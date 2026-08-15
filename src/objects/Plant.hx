package objects;

import flixel.FlxG;
import objects.IEdible;

@:publicFields
class Plant extends FlxSprite implements IEdible {
    var isGrowing:Bool = true;
    /**
     * 0 -> 20 | Inedible
     * 20 -> 75 | Edible (Ripe)
     * 75 -> 100 | Inedible
     */
    var lifeSpan:Float = 0;
    var growthRate:Float;

    static inline var RIPE_MIN:Float = 20;
    static inline var RIPE_MAX:Float = 75;
	static inline var SPREAD_RADIUS:Float = 60;
    var isRipe(get, never):Bool;
    var wasRipe:Bool = false;
    var isEdible(get, never):Bool;

    function get_isEdible():Bool return isRipe;
	function get_isRipe():Bool   return lifeSpan >= RIPE_MIN && lifeSpan <= RIPE_MAX;

    function new(x:Float, y:Float) {
        super(x, y);
		growthRate = FlxG.random.float(0.2, 5.2);
        wasRipe = isRipe;
		loadGraphic('res/${isRipe ? 'plant' : 'plant-unripe'}.png');
    }

    override function update(dt:Float) {
		lifeSpan += dt * growthRate;

        if (lifeSpan >= 100) {
            reproduce();
            kill();
        }

        if (isRipe != wasRipe) {
            wasRipe = isRipe;
            loadGraphic('res/${isRipe ? 'plant' : 'plant-unripe'}.png');
        }

        super.update(dt);
    }

    function getEaten():Float {
        var nutrition = isRipe ? 35.0 : 5.0;
        reproduce();
        kill();
        return nutrition;
    }

	function reproduce() {
		var count = FlxG.random.int(0, FlxG.random.int(1, 3));

		for (i in 0...count) {
			var angle = FlxG.random.float(0, 360);
			var dist = FlxG.random.float(10, SPREAD_RADIUS);
			var rad = angle * Math.PI / 180;

			var newX = x + Math.cos(rad) * dist;
			var newY = y + Math.sin(rad) * dist;

			Game.plants.add(new Plant(newX, newY));
		}
	}
}
