package objects;

import flixel.FlxG;

@:publicFields
class Pond extends FlxSprite {
    function new(x:Float, y:Float) {
        super(x, y);

        loadGraphic('res/pond.png');
        immovable = true;
    }

    function getDrunk():Float {
        return FlxG.random.float(30, 50);
    }
}
