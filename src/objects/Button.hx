package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

@:publicFields
class Button extends FlxSpriteGroup {
	var background:FlxSprite;
	var text_obj:FlxText;
	var onClick:Void->Void;

	function new(x:Float, y:Float, text:String, onClick:Void->Void) {
		super(x, y);

		this.onClick = onClick;

		background = new FlxSprite();
		background.makeGraphic(60, 60, FlxColor.WHITE);
		add(background);

		text_obj = new FlxText(0, 0, 60, text, 24);
		text_obj.alignment = CENTER;
		text_obj.color = FlxColor.BLACK;
		add(text_obj);
	}

	override function update(dt:Float) {
		super.update(dt);

		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(background)) {
			onClick();
		}
	}
}