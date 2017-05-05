import {NgModule} from '@angular/core';
import {MdSidenavModule, MdSliderModule, MdToolbarModule} from '@angular/material';
import {RouterModule} from '@angular/router';
import {BetaRegisterComponent} from '../cyph/components/beta-register.component';
import {CheckoutComponent} from '../cyph/components/checkout.component';
import {DialogAlertComponent} from '../cyph/components/dialog-alert.component';
import {DialogConfirmComponent} from '../cyph/components/dialog-confirm.component';
import {DialogImageComponent} from '../cyph/components/dialog-image.component';
import {HelpComponent} from '../cyph/components/help.component';
import {CyphCommonModule} from '../cyph/modules/cyph-common.module';
import {CyphWebModule} from '../cyph/modules/cyph-web.module';
import {PotassiumService} from '../cyph/services/crypto/potassium.service';
import {DatabaseService} from '../cyph/services/database.service';
import {NotificationService} from '../cyph/services/notification.service';
import {appRoutes} from './app-routes';
import {AppComponent} from './app.component';
import {AppService} from './app.service';
import {DemoChatRootComponent} from './demo-chat-root.component';
import {DemoComponent} from './demo.component';
import {DemoService} from './demo.service';
import {MockDatabaseService} from './mock-database.service';
import {MockPotassiumService} from './mock-potassium.service';
import {RouterComponent} from './router.component';
import {SilentNotificationService} from './silent-notification.service';


/**
 * Angular module for Cyph home page.
 */
@NgModule({
	bootstrap: [RouterComponent],
	declarations: [
		AppComponent,
		BetaRegisterComponent,
		DemoChatRootComponent,
		CheckoutComponent,
		DemoComponent,
		RouterComponent
	],
	entryComponents: [
		BetaRegisterComponent,
		DialogAlertComponent,
		DialogConfirmComponent,
		DialogImageComponent,
		HelpComponent
	],
	imports: [
		RouterModule.forRoot(appRoutes),
		CyphCommonModule,
		CyphWebModule,
		MdSidenavModule,
		MdSliderModule,
		MdToolbarModule
	],
	providers: [
		AppService,
		DemoService,
		{
			provide: DatabaseService,
			useClass: MockDatabaseService
		},
		{
			provide: NotificationService,
			useClass: SilentNotificationService
		},
		{
			provide: PotassiumService,
			useClass: MockPotassiumService
		}
	]
})
/* tslint:disable-next-line:no-stateless-class */
export class AppModule {
	constructor () {}
}
