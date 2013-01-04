package controllers
{
	import ASclasses.Constants;
	
	import ASfiles.ProviderConstants;
	
	import components.AutoComplete;
	import components.home.ViewPatient;
	import components.modules.TeamModule;
	import components.popups.InactivityAlertPopup;
	import components.popups.UserContextMenu;
	import components.popups.VerifyCredentialsPopup;
	import components.popups.preferences.PreferencesPopup;
	
	import enum.RiskLevel;
	import enum.UrgencyType;
	import enum.ViewModeType;
	
	import events.ApplicationDataEvent;
	import events.ApplicationEvent;
	import events.AuthenticationEvent;
	import events.AutoCompleteEvent;
	import events.ProfileEvent;
	
	import external.TabBarPlus.plus.TabBarPlus;
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import models.Chat;
	import models.ChatSearch;
	import models.Message;
	import models.ModuleMappable;
	import models.PatientModel;
	import models.PatientsModel;
	import models.Preferences;
	import models.ProviderApplicationModel;
	import models.ProviderModel;
	import models.SavedSearch;
	import models.TeamAppointmentsModel;
	import models.UserModel;
	import models.UserPreferences;
	import models.modules.AppointmentsModel;
	import models.modules.MedicationsModel;
	import models.modules.MessagesModel;
	import models.modules.advisories.PatientAdvisoryStatus;
	import models.modules.advisories.PublicHealthAdvisoriesModel;
	import models.modules.advisories.PublicHealthAdvisory;
	import models.modules.decisionsupport.RiskFactor;
	import models.modules.decisionsupport.RiskFactorUpdate;
	
	import mx.collections.ArrayCollection;
	import mx.collections.IList;
	import mx.core.INavigatorContent;
	import mx.core.UIComponent;
	import mx.events.CloseEvent;
	import mx.events.ListEvent;
	import mx.managers.PopUpManager;
	import mx.rpc.events.ResultEvent;
	
	import spark.components.DropDownList;
	import spark.events.IndexChangeEvent;
	
	import util.DateFormatters;
	import util.DateUtil;

	[Bindable]
	public class MainController extends Controller
	{
		public var advisoryController:PublicHealthAdvisoriesController;
		public var chatController:ChatController;
		public var decisionSupportController:DecisionSupportController;
		public var patientsController:PatientsController;
		public var teamAppointmentsController:TeamAppointmentsController;
		
		private var autocompleteCallback:Function;
		private var autocomplete:AutoComplete;
		
		private var userContextMenu:UserContextMenu;
		private var userContextMenuTimer:Timer;
		
		private var authenticationPopup:VerifyCredentialsPopup;
		private var inactivityAlert:InactivityAlertPopup;
		
		public function MainController()
		{
			super();
			
			model = new ProviderApplicationModel();
			
			userContextMenuTimer = new Timer( 2000, 1 );
			userContextMenuTimer.addEventListener( TimerEvent.TIMER_COMPLETE, onUserMenuDelay );
			
			advisoryController = new PublicHealthAdvisoriesController();
			chatController = new ChatController();
			decisionSupportController = new DecisionSupportController();
			exerciseController = new ProviderExerciseController();
			immunizationsController = new ProviderImmunizationsController();
			medicalRecordsController = new ProviderMedicalRecordsController();
			medicationsController = new ProviderMedicationsController();
			nutritionController = new ProviderNutritionController();
			patientsController = new PatientsController();
			
			teamAppointmentsController = new TeamAppointmentsController();
			
			advisoryController.model.addEventListener( ApplicationDataEvent.LOADED, onAdvisoriesLoaded );
			
			var lastSynced:Date = new Date( model.today.fullYear, model.today.month, model.today.date );;
			lastSynced.time -= DateUtil.DAY * Math.random();
			
			model.settings = new ArrayCollection
				( 
					[ 
						{id:"preferences", label:"Preferences", tooltip:"Set preferences for general settings, notifications and modules."}, 
						{id:"",label: "---------------------------------------------------", enabled:false }, 
						{id:"sync_status", label: "Last synced " + DateFormatters.syncTime.format( lastSynced ), enabled:false }, 
						{id:"sync", label:"Sync Now"} 
					] 
				);
			
			model.addEventListener( ApplicationDataEvent.LOADED, onAlertsLoaded );
			medicationsController.model.addEventListener( ApplicationDataEvent.LOADED, onMedicationsLoaded );
			patientsController.model.addEventListener( ApplicationDataEvent.LOADED, onPatientsLoaded );
			
			ProviderApplicationModel(model).providersDataService.url = "data/providers.xml";
			ProviderApplicationModel(model).providersDataService.addEventListener( ResultEvent.RESULT, providersResultHandler );
			
			application.addEventListener( AuthenticationEvent.PROMPT, onPromptForAuthentication );
			application.addEventListener( AutoCompleteEvent.SHOW, onShowAutoComplete );
			application.addEventListener( AutoCompleteEvent.HIDE, onHideAutoComplete );
			application.addEventListener( ProfileEvent.SHOW_CONTEXT_MENU, onShowContextMenu );
			
			loadStyles();
		}
		
		override public function showPreferences():UIComponent
		{
			var popup:PreferencesPopup = PopUpManager.createPopUp( application, PreferencesPopup ) as PreferencesPopup;
			popup.preferences = model.preferences.clone() as UserPreferences;
			PopUpManager.centerPopUp( popup );
			
			return popup;
		}
		
		override protected function loadPreferences():void
		{
			if( persistentData 
				&& persistentData.data.hasOwnProperty('preferences') )
			{
				model.preferences = UserPreferences.fromObj( persistentData.data['preferences'] );
			}
			else
			{
				model.preferences = new UserPreferences();
				savePreferences( model.preferences );
			}
			
			processPreferences();
		}
		
		override public function savePreferences( preferences:Preferences ):void
		{
			super.savePreferences(preferences);
			
			persistentData.data['preferences'] = preferences;
			persistentData.flush();
		}
		
		override protected function processPreferences( preferences:Preferences = null ):void
		{
			if( preferences == null ) preferences  = model.preferences;
			
			super.processPreferences( preferences );
			
			if( preferences 
				&& preferences.viewMode != model.preferences.viewMode )
			{
				var state:String = preferences.viewMode == ViewModeType.WIDGET ? Constants.STATE_WIDGET_VIEW : Constants.STATE_LOGGED_IN;
				state = Constants.STATE_LOGGED_IN;	//	widget view not supported yet
				
				application.dispatchEvent( new ApplicationEvent( ApplicationEvent.SET_STATE, true, false, state) );
			}
		}
		
		override protected function onAuthenticated(event:AuthenticationEvent):void
		{
			if( !initialized )
			{
				advisoryController.init();
				chatController.init();
				decisionSupportController.init();
				patientsController.init();
				teamAppointmentsController.init();
			}
			
			super.onAuthenticated(event);
		}
		
		override protected function showHome():void
		{
			setState( Constants.STATE_LOGGED_IN );
		}
		
		protected function onPromptForAuthentication( event:AuthenticationEvent ):void
		{
			if( authenticationPopup
				&& authenticationPopup.parent )
			{
				PopUpManager.removePopUp( authenticationPopup );
			}
			
			authenticationPopup = PopUpManager.createPopUp( application, VerifyCredentialsPopup ) as VerifyCredentialsPopup;
			authenticationPopup.callback = event.onAuthenticatedCallback;
			authenticationPopup.callbackArgs = event.onAuthenticatedCallbackArgs;
			
			authenticationPopup.user = user;
			authenticationPopup.addEventListener( AuthenticationEvent.SUCCESS, onAuthenticationCheckSuccess );
			PopUpManager.centerPopUp( authenticationPopup );
		}
		
		protected function onAuthenticationCheckSuccess( event:AuthenticationEvent ):void
		{
			if( authenticationPopup
				&& authenticationPopup.callback != null )
			{
				authenticationPopup.callbackArgs ? 
					authenticationPopup.callback( authenticationPopup.callbackArgs ) :
					authenticationPopup.callback();
			}
		}
		
		public function getUser( id:int, type:String = null ):UserModel
		{
			var user:UserModel;
			var users:ArrayCollection = ( type == UserModel.TYPE_PROVIDER ? ProviderApplicationModel(model).providersModel.providers : PatientsModel(patientsController.model).patients );
			
			for each(user in users) if( user.id == id ) return user;
			
			return null;
		}
		
		override public function selectSetting( event:IndexChangeEvent ):void
		{
			super.selectSetting(event);
			
			var item:Object = model.settings.getItemAt( event.newIndex );
			
			if( item.id == "preferences" )
			{
				var evt:AuthenticationEvent = new AuthenticationEvent( AuthenticationEvent.PROMPT, true );
				evt.onAuthenticatedCallback = showPreferences;
				application.dispatchEvent( evt );
			}
			else if( item.id == "sync" )
			{
				item.enabled = false;
				
				for each(item in model.preferences)
				{
					if( item.id == "sync_status" )
					{
						item.label = "All information up to date";
					}
				}
			}
			
			DropDownList(event.currentTarget).selectedItem = null;
		}
		
		/**
		 * Autocomplete
		 */
		private function onShowAutoComplete( event:AutoCompleteEvent ):void
		{
			if( !autocomplete )
			{
				autocomplete = new AutoComplete();
				autocomplete.addEventListener( Event.CHANGE, onAutocompleteSelect );
				autocomplete.addEventListener( AutoCompleteEvent.HIDE, onHideAutoComplete );
			}
			
			autocomplete.targetField = event.targetField;
			autocomplete.callbackFunction = event.callbackFunction;
			autocomplete.labelFunction = event.labelFunction;
			autocomplete.dataProvider = event.dataProvider;
			autocomplete.width = event.desiredWidth ? event.desiredWidth : event.targetField.width;
			
			PopUpManager.addPopUp( autocomplete, application );
		}
		
		private function onHideAutoComplete( event:AutoCompleteEvent = null ):void
		{
			if( autocomplete )
			{
				PopUpManager.removePopUp( autocomplete );
			}
		}
		
		private function onAutocompleteSelect( event:IndexChangeEvent ):void
		{
			autocomplete.callbackFunction( event );
		}
		
		/**
		 * User context menu
		 */
		private function onShowContextMenu(event:ProfileEvent):void 
		{
			if( userContextMenu ) hideContextMenu();
			
			userContextMenu = new UserContextMenu();
			userContextMenu.user = event.user;
			userContextMenu.addEventListener( ProfileEvent.VIEW_PROFILE, onUserAction );
			userContextMenu.addEventListener( ProfileEvent.VIEW_APPOINTMENTS, onUserAction );
			userContextMenu.addEventListener( ProfileEvent.SEND_MESSAGE, onUserAction );
			userContextMenu.addEventListener( ProfileEvent.START_CHAT, onUserAction );
			
			userContextMenu.x = application.stage.mouseX;
			userContextMenu.y = application.stage.mouseY;
			
			PopUpManager.addPopUp( userContextMenu, DisplayObject(mx.core.FlexGlobals.topLevelApplication) );
			
			userContextMenuTimer.reset();
			userContextMenuTimer.start();
		}
		
		private function hideContextMenu():void
		{
			if( !userContextMenu ) return;
			
			userContextMenu.removeEventListener( ProfileEvent.VIEW_PROFILE, onUserAction );
			userContextMenu.removeEventListener( ProfileEvent.VIEW_APPOINTMENTS, onUserAction );
			userContextMenu.removeEventListener( ProfileEvent.SEND_MESSAGE, onUserAction );
			userContextMenu.removeEventListener( ProfileEvent.START_CHAT, onUserAction );
			
			PopUpManager.removePopUp( userContextMenu );
		}
		
		private function onUserAction( event:ProfileEvent ):void
		{
			var evt:ApplicationEvent;
			
			if( event.type == ProfileEvent.VIEW_PROFILE )
			{
				if( event.user is ProviderModel )
				{
					evt = new ApplicationEvent( ApplicationEvent.NAVIGATE, true );
					evt.data = ProviderConstants.MODULE_TEAM_PROFILE;
					application.dispatchEvent( evt );
					
					TeamModule( visualDashboardProvider(application).viewStackProviderModules.getChildByName( ProviderConstants.MODULE_TEAM_PROFILE ) ).showTeamMember( event.user );
				}
				else
				{
					patientsController.showPatient( event.user as PatientModel );
				}
			}
			else if( event.type == ProfileEvent.VIEW_APPOINTMENTS )
			{
				if( TeamAppointmentsModel( teamAppointmentsController.model ).selectedProviders.getItemIndex( event.user ) == -1 )
				{
					TeamAppointmentsModel( teamAppointmentsController.model ).selectedProviders.addItem( event.user );
				}
				
				evt = new ApplicationEvent( ApplicationEvent.SET_STATE, true );
				evt.data = Constants.MODULE_APPOINTMENTS;
				application.dispatchEvent( evt );
			}
			else if( event.type == ProfileEvent.SEND_MESSAGE )
			{
				var message:Message = new Message();
				message.recipients = [ event.user ];
				
				evt = new ApplicationEvent( ApplicationEvent.SET_STATE, true );
				evt.data = Constants.MODULE_MESSAGES;
				evt.message = message;
				application.dispatchEvent( evt );
			}
			else if( event.type == ProfileEvent.START_CHAT )
			{
				chatController.chat( user, event.user );
			}
			
			hideContextMenu();
		}
		
		private function onUserMenuDelay( event:TimerEvent ):void
		{
			if( userContextMenu 
				&& userContextMenu.parent )
			{
				if( !userContextMenu.hitTestPoint( application.stage.mouseX, application.stage.mouseY )
					&& !userContextMenu.chatModes.hitTestPoint( application.stage.mouseX, application.stage.mouseY ) )
				{
					hideContextMenu();
				}
				else
				{
					userContextMenuTimer.reset();
					userContextMenuTimer.start();
				}
			}
		}
		
		override protected function onSetState( event:ApplicationEvent ):void
		{
			var child:DisplayObject;
			
			if( event.message )
			{
				if( event.message.recipients ) MessagesModel(messagesController.model).pendingRecipients = event.message.recipients;
				if( event.message.recipientType ) MessagesModel(messagesController.model).pendingRecipientType = event.message.recipientType;
			}
			
			var modPrefix:String = 'mod';
			
			if( event.data != null && event.data.indexOf( modPrefix ) > -1 )
			{
				var id:String = event.data.substr( event.data.indexOf( modPrefix ) + modPrefix.length ).toLowerCase();
				
				if( model.preferences.getPasswordRequiredForModule( id ) )
				{
					var evt:AuthenticationEvent = new AuthenticationEvent( AuthenticationEvent.PROMPT, true );
					evt.onAuthenticatedCallback = setState;
					evt.onAuthenticatedCallbackArgs = event.data;
					application.dispatchEvent( evt );
					
					return;
				}
			}
			
			visualDashboardProvider(application).viewStackMain.verticalScrollPosition = 0;
			visualDashboardProvider(application).viewStackProviderModules.verticalScrollPosition = 0;
			
			super.onSetState(event);
		}
		
		override protected function setState(state:String):Boolean
		{
			var stateSet:Boolean = super.setState(state);
			
			if( stateSet ) return true;
			
			var child:DisplayObject;
				
			//	show relevant application module if valid
			if( visualDashboardProvider(application).viewStackProviderModules
				&& (child = visualDashboardProvider(application).viewStackProviderModules.getChildByName( state ) ) != null )
			{
				visualDashboardProvider(application).viewStackProviderModules.selectedChild = child as INavigatorContent;
				
				if( visualDashboardProvider(application).viewStackMain.selectedIndex != 0 )
				{
					visualDashboardProvider(application).viewStackMain.selectedIndex = 0;
				}
				
				return true;
			}
				
			//	show relevant patient module if valid
			else if( visualDashboardProvider(application).viewStackMain.selectedChild is ViewPatient )
			{
				(visualDashboardProvider(application).viewStackMain.selectedChild as ViewPatient).showModule( state );
				
				return true;
			}
			
			return false;
		}
		
		override protected function onTabClose( event:ListEvent ):void
		{
			super.onTabClose(event);
			
			if( TabBarPlus( event.target.owner).dataProvider is IList )
			{
				var dataProvider:IList = TabBarPlus( event.target.owner).dataProvider as IList;
				var index:int = event.rowIndex;
				
				if( application.currentState == Constants.MODULE_MEDICATIONS ) 
				{
					medicationsController.model.openTabs.splice(index-1,1);
				}
				else if( application.currentState == model.viewMode ) 
				{
					if( dataProvider == visualDashboardProvider(application).viewStackMain ) 
					{
						PatientsModel(patientsController.model).openTabs.splice(index-1,1);
					}
				}
			}
			else 
			{
				trace("Bad data provider");
			}
		}
		
		override protected function onNavigate(event:ApplicationEvent):void
		{
			super.onNavigate(event);
			
			var module:INavigatorContent;
			
			if( event.data is int )
			{
				visualDashboardProvider(application).viewStackProviderModules.selectedIndex = event.data;
				
				module = visualDashboardProvider(application).viewStackProviderModules.selectedChild;
			}
			else if( event.data is String )
			{
				if( application.currentState == Constants.STATE_LOGGED_IN ) 
				{
					var moduleName:String = event.data.toString();
					
					if( visualDashboardProvider(application).viewStackProviderModules.getChildByName( moduleName ) ) 
					{
						module = visualDashboardProvider(application).viewStackProviderModules.getChildByName( moduleName ) as INavigatorContent;
						
						visualDashboardProvider(application).viewStackProviderModules.selectedChild = module;
						
						if( visualDashboardProvider(application).viewStackMain.selectedIndex != 0 )
						{
							visualDashboardProvider(application).viewStackMain.selectedIndex = 0;
						}
					}
				}
			}
			
			visualDashboardProvider(application).viewStackMain.verticalScrollPosition = 0;
			visualDashboardProvider(application).viewStackProviderModules.verticalScrollPosition = 0;
			
			onHideAutoComplete();
		}
		
		override protected function showInactivityTimeout():void
		{
			if( inactivityAlert && inactivityAlert.parent ) return;
			
			inactivityAlert = PopUpManager.createPopUp( application, InactivityAlertPopup, true ) as InactivityAlertPopup;
			inactivityAlert.addEventListener( CloseEvent.CLOSE, onInactivityAlertClose );
			PopUpManager.centerPopUp( inactivityAlert );
		}
		
		override public function logout():void
		{
			for each(var patient:PatientModel in PatientsModel(patientsController.model).openTabs)
			{
				var viewPatient:ViewPatient =  visualDashboardProvider(application).viewStackMain.getChildByName(  "patient" + patient.id ) as ViewPatient;
				visualDashboardProvider(application).viewStackMain.removeChild(  viewPatient );
			}
			
			PatientsModel(patientsController.model).openTabs = [];
			
			super.logout();
		}
		
		private function onInactivityAlertClose( event:CloseEvent ):void
		{
			lastActivity = getTimer();
			
			PopUpManager.removePopUp( inactivityAlert );
		}
		
		private function onAlertsLoaded(event:ApplicationDataEvent):void
		{
			model.removeEventListener( ApplicationDataEvent.LOADED, onAlertsLoaded );
			
			syncMeds();
		}
		
		private function onMedicationsLoaded(event:ApplicationDataEvent):void
		{
			medicationsController.model.removeEventListener( ApplicationDataEvent.LOADED, onMedicationsLoaded );
			
			syncMeds();
		}
		
		private function syncMeds():void
		{
			var model:ProviderApplicationModel = ProviderApplicationModel(model);
			
			if( !model.patientAlertsLoaded || !medicationsController.model.dataLoaded ) return;
			
			//	for all renewal requests, make sure status of corresponding medication is set to pending
			//	should probably be the other way around?
			for each(var alert:Object in model.patientAlerts)
			{
				var type:String = alert.type;
				var alertType:String = alert.alert;
				
				if( type == "Medications" 
					&& alertType == "Renewal Request" )
				{
					var medicationName:String = alert.description;
					
					var medications:ArrayCollection = MedicationsModel(AppProperties.getInstance().controller.medicationsController.model).medicationsData;
					
					for each(var medication:Object in medications)
					{
						if( medication.name == medicationName )
						{
							medication.renewalStatus = "Pending";
						}
					}
				}
			}
		}
		
		private function onPatientsLoaded(event:ApplicationDataEvent):void 
		{
			var patients:ArrayCollection = PatientsModel(patientsController.model).patients;
			
			for each(var patient:PatientModel in patients)
			{
				for each(var riskFactor:RiskFactor in patient.riskFactorGroups)
				{
					for each(var riskFactorSubType:RiskFactor in riskFactor.types)
					{
						if( riskFactorSubType.updates 
							&& riskFactorSubType.updates.length )
						{
							var update:RiskFactorUpdate = riskFactorSubType.updates.getItemAt(0) as RiskFactorUpdate;
							
							if( update.riskLevel == RiskLevel.HIGH )
							{
								var alert:Object = { urgency: UrgencyType.URGENT, date: update.date, type: "Decision Support", alert: "High Risk", description: riskFactor.name };
								
								model.patientAlerts.addItem( alert );
								
								break;
							}
						}	
					}
				}
			}
			
			ChatSearch( chatController.model ).patients = patients;
			
			onAdvisoriesLoaded();
			
			initChatHistory();
		}
		
		private function providersResultHandler(event:ResultEvent):void {
			
			var results:ArrayCollection = event.result.providers.provider;
			
			var teams:Array = [ {label:"All",value:-1} ];
			
			var providers:ArrayCollection = new ArrayCollection();
			
			for each(var result:Object in results)
			{
				var provider:ProviderModel = ProviderModel.fromObj(result);
				provider.id = providers.length;
				providers.addItem( provider );
				
				if( provider.id == ProviderConstants.USER_ID ) 
				{
					provider.available = UserPreferences(model.preferences).chatShowAsAvaiableOnLogin ? "A" : "U";	//	TODO: change to boolean
					user = provider;
				}
				
				var team:Object = {label:"Team " + provider.team, value: provider.team};
				if( teams[provider.team] == null ) teams[provider.team] = team;
			}
			
			if( user
				&& persistentData 
				&& persistentData.data.hasOwnProperty('savedSearches') )
			{
				var savedSearches:ArrayCollection = new ArrayCollection();
				
				for each(var search:Object in persistentData.data.savedSearches)
				{
					savedSearches.addItem( SavedSearch.fromObj( search ) );
				}
				
				ProviderModel( user ).savedSearches = savedSearches;
			}
			
			
			ProviderApplicationModel(model).providersModel.providers = ChatSearch( chatController.model ).providers = providers;
			ProviderApplicationModel(model).providersModel.providerTeams = new ArrayCollection( teams );
			
			initChatHistory();
		}
		
		private function onAdvisoriesLoaded( event:ApplicationDataEvent = null ):void
		{
			if( !advisoryController.model.dataLoaded && patientsController.model.dataLoaded ) return;
			
			for each(var patient:PatientModel in PatientsModel(patientsController.model).patients)
			{
				for each(var advisoryStatus:PatientAdvisoryStatus in patient.advisories)
				{
					var advisory:PublicHealthAdvisory = advisoryController.getAdvisoryById( advisoryStatus.advisoryId );
					
					if( advisory )
					{
						if( advisoryStatus.riskLevel == RiskLevel.LOW || advisoryStatus.riskLevel == RiskLevel.HIGH )
						{
							advisory.update.addAtRiskInNetwork( patient );
						}
						else if( advisoryStatus.riskLevel == RiskLevel.AFFECTED )
						{
							advisory.update.addAffectedInNetwork( patient );
						}
					}
				}
			}
		}
		
		private function initChatHistory():void
		{
			if( !ChatSearch( chatController.model ).providers 
				|| !ChatSearch( chatController.model ).patients ) return;
			
			var user:UserModel = ChatSearch(chatController.model).getUser( ProviderConstants.USER_ID, UserModel.TYPE_PROVIDER );
			
			var today:Date = model.today;
			var time:Number = today.getTime();
			
			var defs:Array = 
				[ 
					{time: time - (DateUtil.DAY * 1 + DateUtil.DAY * .7 * Math.random()), id: 123, type: UserModel.TYPE_PATIENT},
					{time: time - (DateUtil.DAY * 3 + DateUtil.DAY * .7 * Math.random()), id: 123, type: UserModel.TYPE_PATIENT},
					{time: time - (DateUtil.MONTH * .9 + DateUtil.DAY * .7 * Math.random()), id: 123, type: UserModel.TYPE_PATIENT},
					{time: time - (DateUtil.MONTH * 4 + DateUtil.DAY * 3 + DateUtil.DAY * .7 * Math.random()), id: 1, type: UserModel.TYPE_PROVIDER}
				];
			
			for each(var def:Object in defs)
			{
				var start:Date = new Date();
				start.setTime( def.time );
				
				var end:Date = new Date();
				end.setTime( start.time + (DateUtil.HOUR * Math.random()) );
				
				chatController.saveChat( user, new Chat( user, ChatSearch(chatController.model).getUser( def.id, def.type ), start, end ) );
			}
			
			teamAppointmentsController.model.dataService.send();
		}
		
		override public function getModuleTitle(module:String):String
		{
			var title:String = super.getModuleTitle(module);
			
			if( module == ProviderConstants.MODULE_DECISION_SUPPORT ) return "Decision Support";
			if( module == ProviderConstants.MODULE_TEAM_PROFILE ) return "Team Profile";
			
			return title;
		}
		
		//	TODO: call a load() method on these controllers vs. calling send(), so they can defer loading
		//	until a dependency has been loaded
		override public function loadData( id:String ):Boolean
		{
			if( id == PublicHealthAdvisoriesModel.ID )
			{
				if( !advisoryController.model.dataLoaded ) 
				{
					advisoryController.model.dataService.send();
					
					return true;
				}
			}
			else if( id == TeamAppointmentsModel.ID )
			{
				if( !teamAppointmentsController.model.dataLoaded )
				{
					teamAppointmentsController.model.dataService.send();
					
					return true;
				}
			}
			
			return super.loadData( id );
		}
		
		override public function processModuleMappable( item:ModuleMappable ):void
		{
			super.processModuleMappable(item);
			
			var module:String;
			
			if( item.area == TeamAppointmentsModel.ID )
				module = ProviderConstants.MODULE_TEAM_APPOINTMENTS;
			else if( item.area == "teamprofile" )
				module = ProviderConstants.MODULE_TEAM_PROFILE;
			
			if( module )
			{
				var evt:ApplicationEvent = new ApplicationEvent( ApplicationEvent.SET_STATE, true, false, module );
				application.dispatchEvent( evt );
			}
		}
		
		override protected function get id():String
		{
			return 'visualDashboardProvider';
		}
	}
}