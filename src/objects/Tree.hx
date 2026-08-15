package objects;

import flixel.FlxG;
import flixel.util.FlxTimer;
import objects.IEdible;

@:publicFields
class Tree extends FlxSprite implements IEdible {
    var hasApple:Bool = true;
    var regrowTimer:FlxTimer = new FlxTimer();

    static inline var REGROW_MIN:Float = 20;
    static inline var REGROW_MAX:Float = 45;

    var isEdible(get, never):Bool;
    function get_isEdible():Bool return hasApple;

    function new(x:Float, y:Float) {
        super(x, y);
		immovable = true;
        loadGraphic('res/tree-apple.png');
    }

    function getEaten():Float {
        if (!hasApple) return 0; // shoudlnt happen but.. just incase

        hasApple = false;
        loadGraphic('res/tree.png');
        regrowTimer.start(FlxG.random.float(REGROW_MIN, REGROW_MAX), (_) -> {
            hasApple = true;
            loadGraphic('res/tree-apple.png');
        });

        return FlxG.random.float(15, 60); // NUTRIOUSOS!
    }
}