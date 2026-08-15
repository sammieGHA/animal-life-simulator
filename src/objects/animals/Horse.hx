package objects.animals;

import flixel.FlxG;
import flixel.math.FlxMath;
import objects.*;
import objects.Animal.Genes;

/**
 * TODO:
 *          Implement trees and the apple function (Apple on tree -> horse eats apple off tree -> apple not on tree -> apple regenerates)
 */
class Horse extends Animal {
    var targetTree:Tree;
    var treeTimer:Float = 0;

	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y, inheritedGenes, parentGeneration, parentAName, parentBName, age);
		species = "horse";
		speciesScale = .6;
		loadGraphic('res/horse.png');
	}

	override function seekFood() {
		searchingForFood = true;
		var nearest = findNearestEdible(Game.trees.members);

		if (nearest != null) {
			targetTree = nearest;
			searchingForFood = false;
		} else {
			var angle = FlxG.random.float(0, 360);
			velocity.set(wanderSpeed * .5, 0);
			velocity.rotateByDegrees(angle);
			wanderTimer.start(1.0, function(_) seekFood());
		}
	}

    override function pursueFood(dt:Float) {
        if (targetTree == null) {
            if (!searchingForFood) seekFood();
            return;
        }

        if (!targetTree.alive || !targetTree.hasApple) {
            targetTree = null;
            return;
        }

        treeTimer += dt;
        if (treeTimer >= Animal.RECHECK_INTERVAL) {
            treeTimer = 0;
            checkForCloserTree();
        }

        if (dist(this, targetTree) <= Animal.EAT_DISTANCE) {
            eatFromTree(targetTree);
            return;
        }

        var dx = targetTree.x - x;
        var dy = targetTree.y - y;
        var ang = Math.atan2(dy, dx);
        velocity.set(wanderSpeed, 0);
        velocity.rotateByRadians(ang);
    }

    function checkForCloserTree() {
        if (targetTree == null) return;

        var nearest:Tree = null;
        var nearestDist:Float = dist(this, targetTree);

        for (t in Game.trees.members) {
            if (t == null || !t.alive || t == targetTree || !t.hasApple) continue;

            if (dist(this, t) < nearestDist) {
                nearestDist = dist(this, t);
                nearest = t;
            }
        }

        if (nearest != null && nearestDist < dist(this, targetTree) * Animal.SWITCH_MARGIN)
            targetTree = nearest;
    }

    function eatFromTree(tree:Tree) {
        hunger -= tree.getEaten();
        energy += FlxG.random.float(20, 60);
        thirst -= FlxG.random.float(5, 12);
        rebound();
        targetTree = null;
        searchingForFood = false;
        priority = NOTHING;
        wander();
    }

    override function eat(plant:Plant) {}
}