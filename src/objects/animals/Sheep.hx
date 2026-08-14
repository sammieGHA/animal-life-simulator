package objects.animals;

import objects.Animal;

class Sheep extends Animal {
	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y, inheritedGenes, parentGeneration, parentAName, parentBName, age);
		species = "sheep";
		loadGraphic('res/sheep.png');
	}
}