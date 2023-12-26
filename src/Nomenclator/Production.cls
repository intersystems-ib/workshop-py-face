Class Nomenclator.Production Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="Nomenclator.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="Nomenclator.FaceChecker" Category="" ClassName="Nomenclator.FaceChecker" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">	
    <Setting Target="Adapter" Name="FilePath">/shared/JPG</Setting>
	<Setting Target="Adapter" Name="FileSpec">*.jpg</Setting>
    <Setting Target="Host" Name="KnownsPath">/shared/knowns</Setting>
    <Setting Target="Host" Name="ResultsPath">/shared/results</Setting>
    <Setting Target="Host" Name="UnknownsPath">/shared/unknowns</Setting>
    <Setting Target="Host" Name="ModelDetectorFilePath">/shared/mobilenet_graph.pb</Setting>
    <Setting Target="Host" Name="ModelRecognitionFilePath">/shared/facenet_keras_weights.h5</Setting>
  </Item>
</Production>
}

}
