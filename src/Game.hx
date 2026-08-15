package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import objects.*;
import objects.animals.*;

typedef AnimalSpawner = {
	var weight:Float;
	var create:(x:Float, y:Float) -> Animal;
}

enum Day {
	DAY;
	NIGHT;
}

class Game extends FlxState
{
	var gameCamera:FlxCamera;
	var hudCamera:FlxCamera;

	var animalCText:FlxText;
	var animalStatText:FlxText;

	public static var animals:FlxTypedGroup<Animal>;
	public static var plants:FlxTypedGroup<Plant>;
	public static var ponds:FlxTypedGroup<Pond>;
	public static var trees:FlxTypedGroup<Tree>;

	var selectedAnimal:Animal;

	public static var animalCount = 0;
	public static var curDay:Day = DAY;
	var dayTimer:FlxTimer = new FlxTimer();

	static inline var DAY_LENGTH:Float = 60;
	static inline var NIGHT_LENGTH:Float = 40;

	static inline var CAM_SPEED:Float = 290;
	static inline var ZOOM_SPEED:Float = .2;

	var averageTimer:FlxTimer = new FlxTimer();

	static inline var DAY_COLOR:FlxColor = 0xff4CAF50;
	static inline var NIGHT_COLOR:FlxColor = 0xff1B3A1F;
	var nightOverlay:FlxSprite;
	var overlayCamera:FlxCamera;

	static inline var NIGHT_OVERLAY_ALPHA:Float = .75;
	static inline var OVERLAY_FADE_DURATION:Float = 10;

	var sightRangeIndicator:FlxSprite;

	/**
	 * these are fallbacks dont edit them
	 */
	var animalAmount:Int = 600;
	var predatorAmount:Int = 30;
	var plantAmount:Int = 800;
	var pondAmount:Int = 5;

	public static var instance:Game;
	public var audioListener:FlxSprite;

	var animalSpawners:Array<AnimalSpawner> = [
		{ weight: 1, create: (x, y) -> new Cow(x, y, null, null, null, null, 45.0) },
		{ weight: 1, create: (x, y) -> new Sheep(x, y, null, null, null, null, 45.0) },
		{ weight: .50, create: (x, y) -> new Horse(x, y, null, null, null, null, 45.0) }
	];

	public function new(animalAmount:Int, predatorAmount:Int, plantAmount:Int, pondAmount:Int) {
		super();

		animalCount = 0;
		curDay = DAY;
		FlxG.timeScale = 1;

		this.animalAmount = animalAmount;
		this.predatorAmount = predatorAmount;
		this.plantAmount = plantAmount;
		this.pondAmount = pondAmount;
	}

	override public function create()
	{
		super.create();
		instance = this;
		FlxG.sound.music.stop();

		audioListener = new FlxSprite();
		audioListener.makeGraphic(1, 1);
		audioListener.visible = false;
		add(audioListener);

		gameCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		FlxG.cameras.add(gameCamera);
		gameCamera.bgColor = curDay == DAY ? DAY_COLOR : NIGHT_COLOR;

		overlayCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		overlayCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overlayCamera, false);

		hudCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		hudCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(hudCamera, false);

		nightOverlay = new FlxSprite();
		nightOverlay.makeGraphic(FlxG.width, FlxG.height, 0xFF0a0a2e);
		nightOverlay.scrollFactor.set(0, 0);
		nightOverlay.camera = overlayCamera;
		nightOverlay.alpha = curDay == NIGHT ? NIGHT_OVERLAY_ALPHA : 0;
		add(nightOverlay);

		ponds = new FlxTypedGroup<Pond>();
		add(ponds);

		for (i in 0...pondAmount) {
			var pond = new Pond(FlxG.random.float(-1000, 1000), FlxG.random.float(-1000, 1000));
			pond.camera = gameCamera;
			ponds.add(pond);
		}

		animals = new FlxTypedGroup<Animal>();
		add(animals);

		for (i in 0...animalAmount) {
			var spawner = pickRandomSpawner(animalSpawners);
			var animal = spawner.create(FlxG.random.float(-1000, 1000), FlxG.random.float(-1000, 1000));
			animal.camera = gameCamera;
			animals.add(animal);
		}

		for (i in 0...predatorAmount) {
			var pred = new objects.animals.Predator(FlxG.random.float(-1000, 1000), FlxG.random.float(-1000, 1000), null, null, null, null, 45.0);
			pred.camera = gameCamera;
			animals.add(pred);
		}

		sightRangeIndicator = new FlxSprite();
		sightRangeIndicator.camera = gameCamera;
		sightRangeIndicator.visible = false;
		add(sightRangeIndicator);

		plants = new FlxTypedGroup<Plant>();
		add(plants);

		for (i in 0...plantAmount) {
			var plant = new Plant(FlxG.random.float(-2000, 2000), FlxG.random.float(-2000, 2000));
			plant.camera = gameCamera;
			plants.add(plant);
		}

		trees = new FlxTypedGroup<Tree>();
		add(trees);

		for (i in 0...Std.int(plantAmount / 2)) {
			var tree = new Tree(FlxG.random.float(-1500, 1500), FlxG.random.float(-1500, 1500));
			tree.camera = gameCamera;
			trees.add(tree);
		}

		animalCText = new FlxText(10, 10, 0, "", 24);
		animalCText.scrollFactor.set(0, 0);
		animalCText.camera = hudCamera;
		add(animalCText);

		animalStatText = new FlxText(10, 42, 0, "", 20);
		animalStatText.scrollFactor.set(0, 0);
		animalStatText.camera = hudCamera;
		add(animalStatText);

		animalStatText.font = 'res/pirkkala.ttf';
		animalCText.font = 'res/pirkkala.ttf';

		startDayCycle();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		animalCText.text = 'Animals: $animalCount | Time: $curDay | Timescale: ${FlxG.timeScale}';
		if (FlxG.mouse.justPressed)
			trySelectAnimal();
		
		if (selectedAnimal != null && selectedAnimal.alive) {
			animalStatText.text = selectedAnimal.getStats();
			gameCamera.follow(selectedAnimal, LOCKON, .5);
			#if debug
			trace(selectedAnimal.priority);
			#end
		} else {
			selectedAnimal = null;
			gameCamera.follow(null);
			animalStatText.text = "No animal selected";
			sightRangeIndicator.visible = false;
		}

		var dx:Float = 0;
		var dy:Float = 0;

		if (FlxG.keys.anyPressed([LEFT, A]))
			dx -= 2;
		if (FlxG.keys.anyPressed([RIGHT, D]))
			dx += 2;
		if (FlxG.keys.anyPressed([UP, W]))
			dy -= 2;
		if (FlxG.keys.anyPressed([DOWN, S]))
			dy += 2;
		if (FlxG.keys.anyPressed([SHIFT, CONTROL])) {
			dx *= 2;
			dy *= 2;
		}

		if (FlxG.keys.anyJustPressed([ESCAPE, BACKSPACE])) {
			FlxG.switchState(() -> new MainMenu());
		}

		var wheel = FlxG.mouse.wheel;
		if (wheel != 0) gameCamera.zoom += wheel * ZOOM_SPEED;
		gameCamera.zoom = Math.max(.25, gameCamera.zoom);

		FlxG.timeScale = Math.max(0, FlxG.timeScale);
		if (FlxG.keys.justPressed.E) FlxG.timeScale += .25;
		if (FlxG.keys.justPressed.Q && FlxG.timeScale >= 0) FlxG.timeScale -= .25;

		gameCamera.scroll.x += dx * CAM_SPEED * elapsed;
		gameCamera.scroll.y += dy * CAM_SPEED * elapsed;
		audioListener.x = gameCamera.scroll.x + gameCamera.width / (2 * gameCamera.zoom);
		audioListener.y = gameCamera.scroll.y + gameCamera.height / (2 * gameCamera.zoom);
	}

	function trySelectAnimal()
	{
		var worldPos = FlxG.mouse.getWorldPosition(gameCamera);
		var found:Animal = null;

		animals.forEachAlive(function(a:Animal)
		{
			if (found == null && a.overlapsPoint(worldPos, true, gameCamera))
			{
				found = a;
			}
		});

		worldPos.put();
		selectedAnimal = found;
	}

	function startDayCycle() {
		var duration = curDay == DAY ? DAY_LENGTH : NIGHT_LENGTH;
		dayTimer.start(duration, function(_) {
			curDay = curDay == DAY ? NIGHT : DAY;

			var targetAlpha = curDay == NIGHT ? NIGHT_OVERLAY_ALPHA : 0;
			FlxTween.tween(nightOverlay, {alpha: targetAlpha}, OVERLAY_FADE_DURATION, {ease: FlxEase.quadInOut});

			startDayCycle();
		});
	}

	function pickRandomSpawner(spawners:Array<AnimalSpawner>):AnimalSpawner {
		var totalWeight = 0.0;
		for (s in spawners)
			totalWeight += s.weight;

		var roll = FlxG.random.float(0, totalWeight);
		var cumulative = 0.0;

		for (s in spawners) {
			cumulative += s.weight;
			if (roll <= cumulative)
				return s;
		}

		return spawners[spawners.length - 1];
	}
}
