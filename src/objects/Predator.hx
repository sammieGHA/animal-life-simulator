package objects;

import flixel.FlxG;
import flixel.math.FlxMath;
import objects.Animal;

class Predator extends Animal {
    var preyTarget:Animal;
    var preyRecheckTimer:Float = 0;

    static inline var HUNT_DISTANCE:Float = 20;
    static inline var PREDATOR_SIGHT_MULT:Float = 1.3;

	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y, inheritedGenes, parentGeneration, parentAName, parentBName, age);
		isPredator = true;
		loadGraphic('res/predator.png');
	}

    override function seekFood() {
        searchingForFood = true;

        var nearest:Animal = null;
        var sightRange = Animal.BASE_SIGHT_RANGE * genes.sightRangeMult * PREDATOR_SIGHT_MULT;
        var nearestDist:Float = sightRange;

        for (a in Game.animals.members) {
            if (a == null || a == this || !a.alive || a.isPredator || a.isBeingHunted)
                continue;

            var d = FlxMath.distanceBetween(this, a);
            if (d < nearestDist) {
                nearestDist = d;
                nearest = a;
            }
        }

        if (nearest != null) {
            preyTarget = nearest;
            preyTarget.isBeingHunted = true;
            searchingForFood = false;
        } else {
            var angle = FlxG.random.float(0, 360);
            velocity.set(wanderSpeed * .5, 0);
            velocity.rotateByDegrees(angle);
            wanderTimer.start(1.0, function(_) seekFood());
        }
    }

    override function pursueFood(dt:Float) {
        if (preyTarget == null) {
            if (!searchingForFood) seekFood();
            return;
        }

        if (!preyTarget.alive) {
            preyTarget = null;
            return;
        }

        preyRecheckTimer += dt;
        if (preyRecheckTimer >= Animal.RECHECK_INTERVAL) {
            preyRecheckTimer = 0;
            checkForCloserPrey();
        }

        var dist = FlxMath.distanceBetween(this, preyTarget);

        if (dist <= HUNT_DISTANCE) {
            catchPrey(preyTarget);
            return;
        }

        var dx = preyTarget.x - x;
        var dy = preyTarget.y - y;
        var ang = Math.atan2(dy, dx);
        velocity.set(wanderSpeed, 0);
        velocity.rotateByRadians(ang);
    }

    function checkForCloserPrey() {
        if (preyTarget == null) return;

        var curDist = FlxMath.distanceBetween(this, preyTarget);
        var nearest:Animal = null;
        var nearestDist:Float = curDist;

        for (a in Game.animals.members) {
            if (a == null || a == this || a == preyTarget || !a.alive || a.isPredator || a.isBeingHunted) continue;
            var d = FlxMath.distanceBetween(this, a);
            if (d< nearestDist) {
                nearestDist = d;
                nearest = a;
            }

        }

        if (nearest != null && nearestDist < curDist * Animal.SWITCH_MARGIN) {
            preyTarget.isBeingHunted = false;
            preyTarget = nearest;
            preyTarget.isBeingHunted = true;
        }
    }

    function catchPrey(prey:Animal) {
        hunger -= 60;
        energy += FlxG.random.float(10, 30);
        thirst -= FlxG.random.float(5, 12);
        rebound();

        prey.die();
        preyTarget = null;
        searchingForFood = false;
        priority = NOTHING;
        wander();
    }

    override function eat(p:Plant) {}
    override function die() {
        if (preyTarget != null)
            preyTarget.isBeingHunted = false;
        super.die();
    }
}