package objects.animals;

import objects.Animal;

/**
 * TODO:
 *          Implement horse only feeding on Trees
 *          Implement trees and the apple function
 * 
 *          For now, horses are just reskinned like Cow and Sheep
 */
class Horse extends Animal {
	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y, inheritedGenes, parentGeneration, parentAName, parentBName, age);
		species = "horse";
		loadGraphic('res/horse.png');
	}
}