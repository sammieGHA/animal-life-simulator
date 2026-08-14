package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import objects.Button;

class MainMenu extends FlxState {
	var animalAmount:Int = 600;
	var predatorAmount:Int = 30;
	var plantAmount:Int = 800;
	var pondAmount:Int = 5;

    var textCounter:FlxText;
    var label:FlxText;
    var bg:FlxSprite;

    override function create() {
        super.create();

        FlxG.mouse.load('res/cursor.png', 1.8, 0, 0);
        FlxG.sound.playMusic('res/musc.ogg');

        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.GRAY);
        add(bg);

        textCounter = new FlxText(0, 30, 0, "", 24);
		textCounter.alignment = CENTER;
        add(textCounter);

        // ANIMAL
        var mAnimals = new Button(40, 100, "-", () -> animalAmount -= 10);
        add(mAnimals);

		var pAnimals = new Button(120, 100, "+", () -> animalAmount += 10);
		add(pAnimals);

        // PRED
		var mPred = new Button(40, mAnimals.y + 80, "-", () -> predatorAmount -= 10);
		add(mPred);

		var pPred = new Button(120, mAnimals.y + 80, "+", () -> predatorAmount += 10);
		add(pPred);

        // PLANT
		var mPlant = new Button(40, pPred.y + 80, "-", () -> plantAmount -= 10);
		add(mPlant);

		var pPlant = new Button(120, pPred.y + 80, "+", () -> plantAmount += 10);
		add(pPlant);

        // POND
		var mPond = new Button(40, pPlant.y + 80, "-", () -> pondAmount -= 1);
		add(mPond);

		var pPond = new Button(120, pPlant.y + 80, "+", () -> pondAmount += 1);
		add(pPond);

        ////

		label = new FlxText(200, 100, 0, 'Animals\n\n\nPredators\n\n\nPlants\n\n\nPonds', 24);
        add(label);
    }

    override function update(dt:Float) {
        if (FlxG.keys.anyJustPressed([SPACE, ENTER])) {
            FlxG.switchState(() -> new Game(animalAmount, predatorAmount, plantAmount, pondAmount));
        }

        textCounter.text = 'Animals: $animalAmount | Predators: $predatorAmount\nPlants: $plantAmount | Ponds: $pondAmount\n\n\n\n\n\n\n\n\n\n\n\n\nspace/enter - play\nesc/bckspce - exit game';
        textCounter.screenCenter(FlxAxes.X);
        for (i in [animalAmount, predatorAmount, plantAmount, pondAmount]) {
			if (i < 0) i = 0;
        }

        super.update(dt);
    }
}