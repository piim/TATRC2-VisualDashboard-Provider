package models.modules.nutrition
{
	import enum.DietClassQuantifier;
	
	import models.ProviderModel;
	
	import mx.collections.ArrayCollection;

	[Bindable]
	public class FoodPlan
	{
		public static const AVERAGE:FoodPlan = new FoodPlan
			(
				"Average diet", 
				"Maintain current weight and nutritive conditions",
				"Eat well balanced meals and do not exceed the daily calorie budget",
				new Date(),
				new ArrayCollection
				(
					[
						new MealCategory
						( 
							'Breakfast',
							new ArrayCollection
							(
								[
									new Meal( null, "3/4 cup bran flakes cereal; 1 medium banana; and1 cup low-fat milk." ),
									new Meal( null, "1 slice whole wheat bread; 1 tsp soft (tub) margarine; and 1 cup orange juice" ),
									new Meal( null, "1 slice French toast, whole grain: 1 medium egg (for French toast); 1 teaspoon oil;" ),
								]
							)
						), 
						new MealCategory
						( 
							'Lunch',
							new ArrayCollection
							(
								[
									new Meal( null, "Grilled chicken breast\nLentil soup\n1 glass of juice" )
								]
							)
						), 
						new MealCategory
						( 
							'Dinner',
							new ArrayCollection
							(
								[
									new Meal( null, "2 fillets of trout; 4 pieces roasted beets; 3 cups of water" )
								]
							)
						), 
						new MealCategory
						( 
							'Snack',
							new ArrayCollection
							(
								[
									new Meal( null, "16 pieces of baby carrots" )
								]
							)
						), 
					]
				),
				new ArrayCollection
				(
					[
						new FoodServing( 'Fruits', 'servings', DietClassQuantifier.EXACTLY, '5-6' ),
						new FoodServing( 'Grains', 'servings', DietClassQuantifier.EXACTLY, '5-6' ),
						new FoodServing( 'Vegetables', 'servings', DietClassQuantifier.EXACTLY, '5-6' ),
						new FoodServing( 'Proteins', 'servings', DietClassQuantifier.MAXIMUM, '3' ),
						new FoodServing( 'Dairy', 'servings', DietClassQuantifier.MAXIMUM, '3' ),
						new FoodServing( 'Sodium', 'milligrams', DietClassQuantifier.EXACTLY, '2,000' ),
						new FoodServing( 'Fats & Oils', 'servings', DietClassQuantifier.EXACTLY, '2-3' ),
						new FoodServing( 'Sugars', 'servings', DietClassQuantifier.LESS_THAN, '1' ),
						new FoodServing( 'Alcohol', 'drinks', DietClassQuantifier.LESS_THAN, '2' ),
						new FoodServing( 'Water', 'cups', DietClassQuantifier.MINIMUM, '8' )
					]
				)
			);
		
		private var _directions:String;
		private var _name:String;
		private var _provider:ProviderModel;
		private var _reasons:String;
		private var _startingDate:Date;
		
		private var _servingCategories:ArrayCollection 
		
		private var _foodsToIncrease:ArrayCollection;
		private var _foodsToLimit:ArrayCollection;
		private var _mealCategories:ArrayCollection;
		
		public var dirty:Boolean;
		
		public function FoodPlan( name:String = "", reasons:String = "", directions:String = "", startingDate:Date = null, 
								  mealCategories:ArrayCollection = null, servingCategories:ArrayCollection = null, 
								  foodsToLimit:ArrayCollection = null, foodsToIncrease:ArrayCollection = null, 
								  provider:ProviderModel = null )
		{
			this.name = name;
			this.reasons = reasons;
			this.directions = directions;
			this.startingDate = startingDate ? startingDate : new Date();
			
			this.mealCategories = mealCategories ? mealCategories : new ArrayCollection();
			this.servingCategories = servingCategories ? servingCategories : new ArrayCollection();
			this.foodsToLimit = foodsToLimit ? foodsToLimit : new ArrayCollection();
			this.foodsToIncrease = foodsToIncrease ? foodsToIncrease : new ArrayCollection();
			
			this.provider = provider;
			
			dirty = false;
		}

		public function get directions():String
		{
			return _directions;
		}

		public function set directions(value:String):void
		{
			_directions = value;
			
			dirty = true;
		}

		public function get name():String
		{
			return _name;
		}

		public function set name(value:String):void
		{
			_name = value;
			
			dirty = true;
		}

		public function get provider():ProviderModel
		{
			return _provider;
		}

		public function set provider(value:ProviderModel):void
		{
			_provider = value;
			
			dirty = true;
		}

		public function get reasons():String
		{
			return _reasons;
		}

		public function set reasons(value:String):void
		{
			_reasons = value;
			
			dirty = true;
		}

		public function get startingDate():Date
		{
			return _startingDate;
		}

		public function set startingDate(value:Date):void
		{
			_startingDate = value;
			
			dirty = true;
		}

		public function get servingCategories():ArrayCollection
		{
			return _servingCategories;
		}

		public function set servingCategories(value:ArrayCollection):void
		{
			_servingCategories = value;
			
			dirty = true;
		}

		public function get foodsToIncrease():ArrayCollection
		{
			return _foodsToIncrease;
		}

		public function set foodsToIncrease(value:ArrayCollection):void
		{
			_foodsToIncrease = value;
			
			dirty = true;
		}

		public function get foodsToLimit():ArrayCollection
		{
			return _foodsToLimit;
		}

		public function set foodsToLimit(value:ArrayCollection):void
		{
			_foodsToLimit = value;
			
			dirty = true;
		}

		public function get mealCategories():ArrayCollection
		{
			return _mealCategories;
		}

		public function set mealCategories(value:ArrayCollection):void
		{
			_mealCategories = value;
			
			dirty = true;
		}


	}
}