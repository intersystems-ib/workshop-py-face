Class Nomenclator.FaceChecker Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

Property KnownsPath As %String(MAXLEN = 200);

Property UnknownsPath As %String(MAXLEN = 200);

Property ResultsPath As %String(MAXLEN = 200);

Property ModelDetectorFilePath As %String(MAXLEN = 200);

Property ModelRecognitionFilePath As %String(MAXLEN = 200);

Parameter SETTINGS = "KnownsPath,UnknownsPath,ResultsPath,ModelDetectorFilePath,ModelRecognitionFilePath";

Method OnProcessInput(pInput As %Stream.FileBinary, Output pOutput As %RegisteredObject) As %Status
{
	Set status = $$$OK
	
	try {
		Set tFileName= pInput.Filename
		Set directoryExists = ##class(%File).DirectoryExists(..KnownsPath)
		if ('directoryExists)
		{
			set st = $$$ERROR($$$GeneralError, "Directory folder does not exist")
		}
		else 
		{
			// Change '/' character for '\' in Windows
			set st = ##class(%File).CopyFile(tFileName,..UnknownsPath_"/"_$piece(tFileName,"/",*))
			if ('st)
			{
				$$$TRACE("Error copying file")
			}
		}
		$$$TRACE("Processing "_$piece(tFileName,"/",*))

		Set test = ..Checker()
		
		// Change '/' character for '\' in Windows
		set st = ##class(%File).Delete(..UnknownsPath_"/"_$piece(tFileName,"/",*))
		if (test '= "")
		{
			$$$TRACE(test)
		}
		else
		{
			$$$TRACE("No match for "_$piece(tFileName,"/",*))
		}
	}
	catch ex {
		set status = ex.AsStatus()
	}
	
	
	Quit status
}

Method Checker() As %String [ Language = python ]
{
	
	import tensorflow as tf
	
	from tensorflow import keras
	
	from tensorflow.keras import backend as K
	
	from keras.models import load_model
	
	from keras_facenet.inception_resnet_v1 import InceptionResNetV1
	
	import cv2
	
	import numpy as np
	
	import matplotlib.pyplot as plt
	
	import os
	
	# Escaping special characters to work in Windows, not required in Linux or Docker containers
	DIR_KNOWNS = self.KnownsPath.replace('\\', '\\\\')
	DIR_UNKNOWNS = self.UnknownsPath.replace('\\', '\\\\')
	DIR_RESULTS = self.ResultsPath.replace('\\', '\\\\')
	FILE_DETECTOR = self.ModelDetectorFilePath.replace('\\', '\\\\')
	FILE_RECOGNITION = self.ModelRecognitionFilePath.replace('\\', '\\\\')
	
	with tf.io.gfile.GFile(FILE_DETECTOR,"rb") as f:
		graph_def = tf.compat.v1.GraphDef()
		graph_def.ParseFromString(f.read())

	with tf.Graph().as_default() as mobilenet:
		tf.import_graph_def(graph_def,name="")
	
	# Loading image
	def load_image(DIR, NAME):
		return cv2.cvtColor(cv2.imread(f'{DIR}/{name}'), cv2.COLOR_BGR2RGB)
	
	def detect_faces(image, score_threshold=0.7):
		global boxes, scores
		(imh, imw) = image.shape[:-1]
		img = np.expand_dims(image,axis=0)
    
		# Initialize mobilenet
		sess = tf.compat.v1.Session(graph=mobilenet)
		image_tensor = mobilenet.get_tensor_by_name('image_tensor:0')
		boxes = mobilenet.get_tensor_by_name('detection_boxes:0')
		scores = mobilenet.get_tensor_by_name('detection_scores:0')
    
		# Prediction (detection)
		(boxes, scores) = sess.run([boxes, scores], feed_dict={image_tensor:img})
    
    	# Adjusting size of boxes and scores
		boxes = np.squeeze(boxes,axis=0)
		scores = np.squeeze(scores,axis=0)
    
		# Debuging bounding boxes
		idx = np.where(scores>=score_threshold)[0]
    
		# Creation of bounding boxes
		bboxes = []
		for index in idx:
			ymin, xmin, ymax, xmax = boxes[index,:]
			(left, right, top, bottom) = (xmin*imw, xmax*imw, ymin*imh, ymax*imh)
			left, right, top, bottom = int(left), int(right), int(top), int(bottom)
			bboxes.append([left,right,top,bottom])

		return bboxes
	
	# Drawing bounding boxes
	def draw_box(image,box,color,line_width=6):
		if box==[]:
			return image
		else:
			cv2.rectangle(image,(box[0],box[2]),(box[1],box[3]),color,line_width)
		return image
		
	# Extracting faces
	def extract_faces(image,bboxes,new_size=(160,160)):
		cropped_faces = []
		for box in bboxes:
			left, right, top, bottom = box
			face = image[top:bottom,left:right]
			cropped_faces.append(cv2.resize(face,dsize=new_size))
		return cropped_faces
	
	facenet = InceptionResNetV1(
        input_shape=(160, 160, 3),
        classes=128,
    )
	
	facenet.load_weights(FILE_RECOGNITION)
	
	def compute_embedding(model,face):
		face = face.astype('float32')
    
		mean, std = face.mean(), face.std()
		face = (face-mean) / std
    
		face = np.expand_dims(face,axis=0)
    
		embedding = model.predict(face)
		return embedding
			
	def compare_faces(embs_ref, emb_desc, umbral=1.1):
		distancias = []
		for emb_ref in embs_ref:
			distancias.append(np.linalg.norm(emb_ref-emb_desc))
		distancias = np.array(distancias)
		return distancias, list(distancias<=umbral)
	
	isMatch = ''
	
	# Embeddings reference
	known_embeddings = []
	for name in os.listdir(DIR_KNOWNS):
		if name.endswith('.jpg'):
			image = load_image(DIR_KNOWNS,name)
			bboxes = detect_faces(image)					
			face = extract_faces(image,bboxes)
			if len(face) > 0 :
				known_embeddings.append(compute_embedding(facenet,face[0]))				
					
	# Searching matches for knowns faces		
	for name in os.listdir(DIR_UNKNOWNS):
		if name.endswith('.jpg'):
			image = load_image(DIR_UNKNOWNS,name)
			bboxes = detect_faces(image)
			faces = extract_faces(image,bboxes)
      
			# Computing embedding for each face
			img_with_boxes = image.copy()
			for face, box in zip(faces,bboxes):
				emb = compute_embedding(facenet,face)

				puntuacion, reconocimiento = compare_faces(known_embeddings,emb)

				if any(reconocimiento):							
					isMatch = isMatch + ' ' + name + ' match!'
					img_with_boxes = draw_box(img_with_boxes,box,(0,255,0))
				else:
					img_with_boxes = draw_box(img_with_boxes,box,(255,0,0))
            
			cv2.imwrite(f'{DIR_RESULTS}/{name}',cv2.cvtColor(img_with_boxes,cv2.COLOR_RGB2BGR))
	
	return isMatch
}

}
