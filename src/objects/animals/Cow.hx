package objects.animals;

import objects.Animal;

class Cow extends Animal {
	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y, inheritedGenes, parentGeneration, parentAName, parentBName, age);
		species = "cow";
		loadGraphic('res/cow.png');
	}
}