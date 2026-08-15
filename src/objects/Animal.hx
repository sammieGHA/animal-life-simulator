package objects;

import Game.Day;
import Random;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import objects.*;
import objects.animals.*;

typedef Genes = {
	var wanderSpeedMult:Float;
	var thirstDrainMult:Float;
	var hungerDrainMult:Float;
	var sizeMult:Float;
	var sightRangeMult:Float;
	var reactionTimeMult:Float;
}

enum Priority {
	NOTHING;
	FOOD;
	WATER;
	ENERGY;
	MATE;
	FLEE;
}

/**
 * TODO: Replace "DISTANCE" vars with `FlxG.overlap(a, b);`
 */
@:publicFields
class Animal extends FlxSprite {
	var hunger:Float = 0;
	var thirst:Float = 100;
	var energy:Float = 100;
	var mate_level:Float = 0;

	var priority:Priority;

	var wanderAngle:Float = 0;
	var wanderTimer:FlxTimer = new FlxTimer();
	var wanderSpeed:Float;

	var mateTarget:Animal;
	var isMating:Bool;
	var isSleeping:Bool = false;
	var searchingForMate:Bool = false;

	var name:String;
	var species:String = "animal";

	var foodTarget:Plant;
	var searchingForFood:Bool = false;
	var foodRecheckTimer:Float = 0;
	var mateRecheckTimer:Float = 0;
	var waterTarget:Pond;
	var searchingForWater:Bool = false;
	var waterRecheckTimer:Float = 0;

	var levelToSeekFood:Float;
	var levelToSeekWater:Float;
	var age:Float = 0;
	var isAdult:Bool = false;

	var sleepTimer:FlxTimer = new FlxTimer();

	var genes:Genes;
	var generation:Int = 1;

	var isPredator:Bool = false;
	var isBeingHunted:Bool = false;

	var fleeTarget:Animal;
	var fleeRecheckTimer:Float = 0;

	var isStupid:Bool = false;
	var threatCheckCounter:Float = 0;
	var hitboxUpdate:Float = 0;

	var fleeMinDurationTimer:Float = 0;

	var pendingPriority:Priority = NOTHING;
	var priorityChangeTimer:Float = 0;
	var speciesScale:Float = 1;

	static inline var BASE_REACTION_TIME:Float = .5;
	static inline var FLEE_MIN_DURATION:Float = 1.0;
	static inline var FLEE_TRIGGER_RANGE:Float = 350;
	static inline var FLEE_SAFE_RANGE:Float = 300;
	static inline var DRINK_DISTANCE:Float = 25;
	static inline var RECHECK_INTERVAL:Float = 1.5;
	static inline var SWITCH_MARGIN:Float = 0.8; 
	static inline var EAT_DISTANCE:Float = 15;
	static inline var MATE_DISTANCE:Float = 20;
	static 		  var MATE_THRES:Float = #if debug 25 #else 0 #end;
	static inline var ADULT_AGE:Float = #if debug 15 #else 45 #end;
	static inline var BABY_SCALE:Float = 0.4;
	static inline var MUTATION_CHANCE:Float = 0.2; // @DEF: 0.2
	static inline var MUTATION_STRENGTH:Float = .4; // @DEF: 0.4
	static inline var DEFECT_CHANCE:Float = 0.02;  // @DEF: .02
	static inline var BASE_SIGHT_RANGE:Float = 800;

	function new(x:Float, y:Float, ?inheritedGenes:Genes, ?parentGeneration:Int, ?parentAName:String, ?parentBName:String, ?age:Float) {
		super(x, y);
		Game.animalCount++;
		priority = NOTHING;
		name = (parentAName != null && parentBName != null) ? combineNames(parentAName, parentBName) : Random.string(FlxG.random.int(2, 8));
		this.age = age == null ? this.age : age;
		genes = inheritedGenes != null ? inheritedGenes : randomGenes();
		generation = parentGeneration != null ? parentGeneration + 1 : 1;
		levelToSeekFood = FlxG.random.float(30, 60);
		levelToSeekWater = FlxG.random.float(10, 40);
		wanderSpeed = FlxG.random.float(100, 140) * genes.wanderSpeedMult;
		isStupid = FlxG.random.bool(2);
		#if !debug MATE_THRES = FlxG.random.float(65, 99); #end

		drag.set(200, 200);
		maxVelocity.set(wanderSpeed, wanderSpeed);
		wander();
	}

	static function combineNames(a:String, b:String):String {
		var aHalf = Math.ceil(a.length / 2);
		var bHalf = Math.floor(b.length / 2);

		var firstPart = a.substr(0, aHalf);
		var secondPart = b.substr(b.length - bHalf, bHalf);

		return firstPart + secondPart;
	}

	override function update(dt:Float) {
		hunger += dt * FlxG.random.float(0.8, 1.2) * genes.hungerDrainMult;
		thirst -= dt * FlxG.random.float(0.8, Game.curDay == DAY ? 2.1 : 1.2) * genes.thirstDrainMult;
		rebound();

		if (!isAdult) {
			age += dt * .2;

			var growth = FlxMath.bound(age / ADULT_AGE, 0, 1);
			var targetScale = (BABY_SCALE + (genes.sizeMult - BABY_SCALE) * growth) * speciesScale;
			scale.set(targetScale, targetScale);
			
			hitboxUpdate += dt;
			if (hitboxUpdate >= .1) {
				hitboxUpdate = 0;
				updateHitbox();
			}

			if (age >= ADULT_AGE) {
				isAdult = true;
				scale.set(genes.sizeMult * speciesScale, genes.sizeMult * speciesScale);
				updateHitbox();
			}
		}

		var previousPriority = priority;
		updatePriority(dt);

		if (priority != previousPriority)
			onPriorityChanged(previousPriority, priority);

		if (hunger >= 100 || thirst <= 0) {
			die();
			return;
		}

		var conditionsMet = 0;
		if (hunger <= 50)
			conditionsMet++;
		if (thirst >= 30)
			conditionsMet++;
		if (energy >= 40)
			conditionsMet++;

		if (#if debug true #else conditionsMet >= 2 #end) {
			mate_level += dt * FlxG.random.float(.2, 3);
		}

		switch (priority) {
			case MATE:
				pursueMate(dt);
				energy -= dt * FlxG.random.float(.01, 1);
			case FOOD:
				pursueFood(dt);
				energy -= dt * FlxG.random.float(.01, 3);
			case WATER:
				pursueWater(dt);
				energy -= dt * FlxG.random.float(.01, 3);
			case FLEE:
				if (!isStupid) pursueFlee(dt);
				energy -= dt * FlxG.random.float(1, 3);
			case NOTHING, ENERGY:
				// already handled dont do anythin with this
		}

		if (!isSleeping)
			energy += dt * .002;
		else
			energy += dt * .2;

		color = isSleeping ? 0x7595CF : FlxColor.WHITE;

		super.update(dt);
	}

	function updatePriority(dt:Float) {
		#if debug if (priority == FOOD && isPredator) trace('is huntin'); #end
		if (isMating || isSleeping)
			return;

		if (!isPredator && !isStupid) {
			if (isBeingHunted && priority != FLEE) {
				var hunter = findNearbyThreat();
				if (hunter != null) {
					priority = FLEE; // no reaction delay because free is more of a reflex
					pendingPriority = FLEE;
					fleeTarget = hunter;
					fleeMinDurationTimer = FLEE_MIN_DURATION;
					return;
				}
			}

			threatCheckCounter += dt;
			if (threatCheckCounter >= .15) {
				threatCheckCounter = 0;
				var nearbyPred = findNearbyThreat();
				if (nearbyPred != null && !nearbyPred.isSleeping && nearbyPred.priority == FOOD) {
					if (priority != FLEE)
						fleeMinDurationTimer = FLEE_MIN_DURATION;
					priority = FLEE;
					pendingPriority = FLEE;
					fleeTarget = nearbyPred;
					return;
				}

				if (priority == FLEE) {
					fleeMinDurationTimer -= .15;
					if (fleeMinDurationTimer <= 0) {
						priority = NOTHING;
						pendingPriority =NOTHING;
						fleeTarget = null;
					}
				}
			} else if (priority == FLEE) {
				return;
			}
		}

		if (priority == FLEE) return;

		var isCommitted = (priority == WATER && waterTarget != null)
			|| (priority == FOOD && foodTarget != null)
			|| (priority == MATE && mateTarget != null);

		var isCritical = (hunger >= 95) || (thirst <= 5);

		if (isCommitted && !isCritical)
			return;

		var desired:Priority;

		if (energy <= 15 && Game.curDay == NIGHT)
			desired = ENERGY;
		else if (hunger >= levelToSeekFood)
			desired = FOOD;
		else if (thirst <= levelToSeekWater)
			desired = WATER;
		else if (isAdult && mate_level >= MATE_THRES && energy >= 35)
			desired = MATE;
		else
			desired = NOTHING;

		if (isCritical) {
			priority = desired;
			pendingPriority = desired;
			priorityChangeTimer = 0;
			return;
		}

		if (desired == priority) {
			pendingPriority = priority;
			priorityChangeTimer = 0; 
			return;
		}

		if (desired != pendingPriority) {
			pendingPriority = desired;
			priorityChangeTimer = BASE_REACTION_TIME * genes.reactionTimeMult * FlxG.random.float(.7, 1.3);
			return;
		}

		priorityChangeTimer -= dt;
		if (priorityChangeTimer <= 0) priority = desired;
	}

	function findNearestEdible<T:FlxSprite>(members:Array<T>, exclude:T = null):T {
		var nearest:T = null;
		var sightRange = BASE_SIGHT_RANGE * genes.sightRangeMult;
		var nearestDist:Float = sightRange;

		for (m in members) {
			if (m == null || !m.alive || m == exclude)
				continue;

			var edible = cast(m, IEdible);
			if (!edible.isEdible)
				continue;

			if (dist(this, m) < nearestDist) {
				nearestDist = dist(this, m);
				nearest = m;
			}
		}

		return nearest;
	}

	function pursueFlee(dt:Float) {
		if (fleeTarget == null || !fleeTarget.alive) {
			fleeTarget = null;
			priority = NOTHING;
			wander();
			return;
		}

		var dist = dist(this, fleeTarget);

		if (dist >= FLEE_SAFE_RANGE) {
			fleeTarget = null;
			priority = NOTHING;
			wander();
			return;
		}

		var dx = x - fleeTarget.x;
		var dy = y - fleeTarget.y;
		var ang = Math.atan2(dy, dx);

		velocity.set(wanderSpeed * 1.4, 0);
		velocity.rotateByRadians(ang);
	}

	function findNearbyThreat():Animal {
		if (isBeingHunted) {
			for (p in Game.animals.members) {
				if (p == null || !p.alive || !p.isPredator) continue;

				var d = dist(this, p);
				if (d <= FLEE_TRIGGER_RANGE * 1.5)
					return p;
			}
		}

		for (p in Game.animals.members) {
			if (p == null || !p.alive || !p.isPredator) continue;
			var d = dist(this, p);
			if (d <= FLEE_TRIGGER_RANGE) return p;
		}

		return null;
	}

	function onPriorityChanged(from:Priority, to:Priority) {
		wanderTimer.cancel();

		switch (to) {
			case NOTHING:
				wander();
			case MATE:
				if (!FlxG.random.bool(80)) {
					priority = NOTHING;
					wander();
					return;
				}

				mateTarget = null;
				seekMate();
			case ENERGY:
				sleep();
			case WATER:
				seekWater();
			case FOOD:
				foodTarget = null;
				seekFood();
			case FLEE:
				wanderTimer.cancel();
				maxVelocity.set(wanderSpeed * 1.4, wanderSpeed * 1.4);
		}
	}

	static function randomGenes():Genes {
		return {
			wanderSpeedMult: FlxG.random.float(.8, 1.8),
			thirstDrainMult: FlxG.random.float(.8, 1.8),
			hungerDrainMult: FlxG.random.float(.8, 1.8),
			sizeMult:        FlxG.random.float(.8, 1.8),
			sightRangeMult:  FlxG.random.float(.8, 1.8),
			reactionTimeMult:FlxG.random.float(.3, 3.8)
		};
	}

	static function inheritGenes(a:Genes, b:Genes):Genes {
		return {
			wanderSpeedMult: mutateGene((a.wanderSpeedMult + b.wanderSpeedMult) / 2, FlxG.random.int(-1, 1)),
			thirstDrainMult: mutateGene((a.thirstDrainMult + b.thirstDrainMult) / 2, FlxG.random.int(-1, 1)),
			hungerDrainMult: mutateGene((a.hungerDrainMult + b.hungerDrainMult) / 2, FlxG.random.int(-1, 1)),
			sizeMult:        mutateGene((a.sizeMult + b.sizeMult) / 2, FlxG.random.int(-1, 1)),
			sightRangeMult:  mutateGene((a.sightRangeMult + b.sightRangeMult) / 2, FlxG.random.int(-1, 1)),
			reactionTimeMult:mutateGene((a.reactionTimeMult + b.reactionTimeMult) / 2, FlxG.random.int(-1, 1))
		};
	}

	static function mutateGene(value:Float, harmDirection:Int = 0):Float {
		if (FlxG.random.bool(DEFECT_CHANCE * 100)) {
			var swing = FlxG.random.float(0.5, 1) * MUTATION_STRENGTH * 2;
			value += harmDirection != 0 ? swing * harmDirection : FlxG.random.float(-1, 1) * swing;
		} else if (FlxG.random.bool(MUTATION_CHANCE * 100)) {
			value += FlxG.random.float(-1, 1) * MUTATION_STRENGTH;
		}

		// trace(value);
		return FlxMath.bound(value, 0.6, 1.8);
	}

	function sleep() {
		isSleeping = true;
		velocity.set(0, 0);
		wanderTimer.cancel();

		sleepTimer.start(FlxG.random.float(10, 25), function (_) wakeUp());
	}

	function wakeUp() {
		isSleeping = false;
		energy += FlxG.random.float(60, 120);
		rebound();
		priority = NOTHING;
		wander();
	}

	function seekMate() {
		searchingForMate = true;

		var nearest:Animal = null;

		var sightRange = BASE_SIGHT_RANGE * genes.sightRangeMult;
		var nearestDist:Float = sightRange;

		for (other in Game.animals.members) {
			if (other == null || other == this || !other.alive)
				continue;
			if (!other.isAdult || other.mate_level < MATE_THRES || other.isMating || other.isPredator != isPredator || other.species != species)
				continue;

			var d = dist(this, other);
			if (d < nearestDist) {
				nearestDist = d;
				nearest = other;
			}
		}

		if (nearest != null) {
			mateTarget = nearest;
			searchingForMate = false;
		} else {
			wanderTimer.start(1.0, function(_) seekMate());
		}
	}

	function pursueMate(dt:Float) {
		if (mateTarget == null) {
			if (!searchingForMate)
				seekMate();
			return;
		}

		if (!mateTarget.alive || mateTarget.isMating) {
			mateTarget = null;
			return;
		}

		mateRecheckTimer += dt;
		if (mateRecheckTimer >= RECHECK_INTERVAL) {
			mateRecheckTimer = 0;
			checkForCloserMate();
		}

		var dist = dist(this, mateTarget);

		if (dist <= MATE_DISTANCE) {
			mateWith(mateTarget);
			return;
		}

		var dx = mateTarget.x - x;
		var dy = mateTarget.y - y;
		var ang = Math.atan2(dy, dx);

		velocity.set(wanderSpeed, 0);
		velocity.rotateByRadians(ang);
	}

	function checkForCloserMate() {
		if (mateTarget == null)
			return;

		var currentDist = dist(this, mateTarget);
		var nearest:Animal = null;
		var nearestDist:Float = currentDist;

		for (other in Game.animals.members) {
			if (other == null || other == this || other == mateTarget || !other.alive)
				continue;
			if (!other.isAdult || other.mate_level < MATE_THRES || other.isMating || other.isPredator != isPredator || other.species != species)
				continue;

			var d = dist(this, other);
			if (d < nearestDist) {
				nearestDist = d;
				nearest = other;
			}
		}

		if (nearest != null && nearestDist < currentDist * SWITCH_MARGIN) {
			mateTarget = nearest;
		}
	}

	function mateWith(other:Animal) {
		if (isMating || other.isMating)
			return;
		isMating = true;
		other.isMating = true;

		var babyX = (x + other.x) / 2;
		var babyY = (y + other.y) / 2;

		var childGeneration = Std.int(Math.max(generation, other.generation));
		var childGenes = inheritGenes(genes, other.genes);

		var baby:Animal = switch (species) {
			case "wolf":  new Predator(babyX, babyY, childGenes, childGeneration, name, other.name);
			case "sheep": new Sheep(babyX, babyY, childGenes, childGeneration, name, other.name);
			case "cow":   new Cow(babyX, babyY, childGenes, childGeneration, name, other.name);
			case "horse": new Horse(babyX, babyY, childGenes, childGeneration, name, other.name);
			default: 
				trace('weird ass child just got made. what are these guys making?');
				new Cow(babyX, babyY, childGenes, childGeneration, name, other.name);
		}

		Game.animals.add(baby);

		energy -= FlxG.random.float(20, 50);
		var sound = FlxG.sound.play('res/birth.ogg');
		sound.proximity(x, y, Game.instance.audioListener, 800, true);

		resetMating();
		other.resetMating();
	}

	function seekFood() {
		searchingForFood = true;
		var nearest = findNearestEdible(Game.plants.members);

		if (nearest != null) {
			foodTarget = nearest;
			searchingForFood = false;
		} else {
			var angle = FlxG.random.float(0, 360);
			velocity.set(wanderSpeed * .5, 0);
			velocity.rotateByDegrees(angle);
			wanderTimer.start(1.0, function(_) seekFood());
		}
	}

	function pursueFood(dt:Float) {
		if (foodTarget == null) {
			if (!searchingForFood)
				seekFood();
			return;
		}

		if (!foodTarget.alive) {
			foodTarget = null;
			return;
		}

		foodRecheckTimer += dt;
		if (foodRecheckTimer >= RECHECK_INTERVAL) {
			foodRecheckTimer = 0;
			checkForCloserFood();
		}

		var dist = dist(this, foodTarget);

		if (dist <= EAT_DISTANCE) {
			eat(foodTarget);
			return;
		}

		var dx = foodTarget.x - x;
		var dy = foodTarget.y - y;
		var ang = Math.atan2(dy, dx);

		velocity.set(wanderSpeed, 0);
		velocity.rotateByRadians(ang);
	}

	function checkForCloserFood() {
		if (foodTarget == null)
			return;

		var currentDist = FlxMath.distanceBetween(this, foodTarget);
		var nearest:Plant = null;
		var nearestDist:Float = currentDist;

		for (p in Game.plants.members) {
			if (p == null || !p.alive || !p.isRipe || p == foodTarget)
				continue;

			var d = FlxMath.distanceBetween(this, p);
			if (d < nearestDist) {
				nearestDist = d;
				nearest = p;
			}
		}

		if (nearest != null && nearestDist < currentDist * SWITCH_MARGIN) {
			foodTarget = nearest;
		}
	}

	function seekWater() {
		searchingForWater = true;

		var nearest:Pond = null;
		var sightRange = BASE_SIGHT_RANGE * genes.sightRangeMult;
		var nearestDist:Float = sightRange;

		for (p in Game.ponds.members) {
			if (p == null || !p.alive)
				continue;

			var d = FlxMath.distanceBetween(this, p);
			if (d < nearestDist) {
				nearestDist = d;
				nearest = p;
			}
		}

		if (nearest != null) {
			waterTarget = nearest;
			searchingForWater = false;
		} else {
			var angle = FlxG.random.float(0, 360);
			velocity.set(wanderSpeed * .5, 0);
			velocity.rotateByDegrees(angle);
			wanderTimer.start(1.0, function(_) seekWater());
		}
	}

	function pursueWater(dt:Float) {
		if (waterTarget == null) {
			if (!searchingForWater)
				seekWater();
			return;
		}

		if (!waterTarget.alive) {
			waterTarget = null;
			return;
		}

		waterRecheckTimer += dt;
		if (waterRecheckTimer >= RECHECK_INTERVAL) {
			waterRecheckTimer = 0;
			checkForCloserWater();
		}

		var dist = FlxMath.distanceBetween(this, waterTarget);

		if (dist <= DRINK_DISTANCE) {
			drink(waterTarget);
			return;
		}

		var dx = waterTarget.x - x;
		var dy = waterTarget.y - y;
		var ang = Math.atan2(dy, dx);

		velocity.set(wanderSpeed, 0);
		velocity.rotateByRadians(ang);
	}

	function checkForCloserWater() {
		if (waterTarget == null)
			return;

		var currentDist = FlxMath.distanceBetween(this, waterTarget);
		var nearest:Pond = null;
		var nearestDist:Float = currentDist;

		for (p in Game.ponds.members) {
			if (p == null || !p.alive || p == waterTarget)
				continue;

			var d = FlxMath.distanceBetween(this, p);
			if (d < nearestDist) {
				nearestDist = d;
				nearest = p;
			}
		}

		if (nearest != null && nearestDist < currentDist * SWITCH_MARGIN) {
			waterTarget = nearest;
		}
	}

	function drink(pond:Pond) {
		thirst += pond.getDrunk();
		energy += FlxG.random.float(0, 20);
		hunger += FlxG.random.float(2, 5);
		rebound();
		waterTarget = null;
		searchingForWater = false;
		priority = NOTHING;
		var sound = FlxG.sound.play('res/drink.ogg');
		sound.proximity(pond.x, pond.y, Game.instance.audioListener, 400, true);
		wander();
	}

	function resetMating() {
		mate_level = 0;
		energy -= FlxG.random.float(2, 20);
		hunger += FlxG.random.float(2, 10);
		thirst -= FlxG.random.float(2, 10);
		rebound();
		isMating = false;
		mateTarget = null;
		searchingForMate = false;

		priority = NOTHING;
		wander();
	}

	function rebound() {
		hunger = FlxMath.bound(hunger, 0, 100);
		thirst = FlxMath.bound(thirst, 0, 100);
		mate_level = FlxMath.bound(mate_level, 0, 100);
		energy = FlxMath.bound(energy, 0, 100);
	}

	function wander() {
		wanderAngle = FlxG.random.float(0, 360);
		pickDir();
	}

	function pickDir() {
		if (priority != NOTHING || energy == 0)
			return;

		wanderAngle += FlxG.random.float(-45, 45);

		var sp = FlxG.random.float(wanderSpeed * .5, wanderSpeed);
		velocity.set(sp, 0);
		velocity.rotateByDegrees(wanderAngle);
		energy -= FlxG.random.float(0.5, 1.5);

		wanderTimer.start(FlxG.random.float(0.4, 0.9), function(_) pickDir());
	}

	function eat(plant:Plant) {
		hunger -= plant.getEaten();
		energy += FlxG.random.float(20, 60);
		thirst -= FlxG.random.float(5, 12);
		rebound();
		foodTarget = null;
		searchingForFood = false;
		priority = NOTHING;
		wander();
	}

	function die() {
		wanderTimer.cancel();
		sleepTimer.cancel();
		Game.animalCount--;
		var sound = FlxG.sound.play('res/die${FlxG.random.int(1, 4)}.ogg');
		sound.proximity(x, y, Game.instance.audioListener, 800, true);
		kill();
	}

	inline function dist(a:FlxSprite, b:FlxSprite):Float {
		var dx = a.x - b.x;
		var dy = a.y - b.y;
		return Math.sqrt(dx * dx + dy * dy);
	}

	function getStats():String {
		return 'H: ${Std.int(hunger)} | T: ${Std.int(thirst)} | E: ${Std.int(energy)} | ML: ${Std.int(mate_level)} | PRI: $priority | NAME: $name\n'
			+ 'AGE: ${Std.int(age)} | ADULT: $isAdult | GEN: $generation\n'
			+ 'ThirstDrainMult: ${FlxMath.roundDecimal(genes.thirstDrainMult, 2)} | '
			+ 'WanderSpeedMult: ${FlxMath.roundDecimal(genes.wanderSpeedMult, 2)}\n'
			+ 'SizeMult: ${FlxMath.roundDecimal(genes.sizeMult, 2)} | '
			+ 'HungerDrainMult: ${FlxMath.roundDecimal(genes.hungerDrainMult, 2)}\n'
			+ 'SightRangeMult: ${FlxMath.roundDecimal(genes.sightRangeMult, 2)}';
	}
}