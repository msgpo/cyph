import {
	AfterViewInit,
	ChangeDetectionStrategy,
	ChangeDetectorRef,
	Component,
	Inject,
	Optional,
	ViewChild
} from '@angular/core';
import {MatBottomSheetRef} from '@angular/material/bottom-sheet';
import {MatDialogRef} from '@angular/material/dialog';
import {BaseProvider} from '../../base-provider';
import {IForm} from '../../proto';
import {StringsService} from '../../services/strings.service';
import {sleep} from '../../util/wait';
import {DynamicFormComponent} from '../dynamic-form';


/**
 * Angular component for confirm dialog.
 */
@Component({
	changeDetection: ChangeDetectionStrategy.OnPush,
	selector: 'cyph-dialog-confirm',
	styleUrls: ['./dialog-confirm.component.scss'],
	templateUrl: './dialog-confirm.component.html'
})
export class DialogConfirmComponent extends BaseProvider implements AfterViewInit {
	/** Cancel button text. */
	public cancel?: string;

	/** Content. */
	public content?: string;

	/** @see DynamicFormComponent */
	@ViewChild(DynamicFormComponent) public dynamicForm?: DynamicFormComponent;

	/** Form for prompt. If defined, will render and return response. */
	public form?: IForm;

	/** Indicates whether content is Markdown. */
	public markdown: boolean	= false;

	/** OK button text. */
	public ok?: string;

	/** If not undefined, will prompt for input. */
	public prompt?: string;

	/** Prompt placeholder text. */
	public promptPlaceholder?: string;

	/** Title. */
	public title?: string;

	/** Indicates whether this is a bottom sheet. */
	public get bottomSheet () : boolean {
		return this.matBottomSheetRef !== undefined;
	}

	/** Closes dialog. */
	public close (ok?: boolean) : void {
		if (this.matDialogRef) {
			this.matDialogRef.close(ok);
		}
		else if (this.matBottomSheetRef) {
			this.matBottomSheetRef.dismiss(ok);
		}
	}

	/** @inheritDoc */
	public async ngAfterViewInit () : Promise<void> {
		await sleep(0);
		this.changeDetectorRef.markForCheck();
	}

	constructor (
		/** @ignore */
		private readonly changeDetectorRef: ChangeDetectorRef,

		/** @ignore */
		@Optional() @Inject(MatBottomSheetRef)
		private readonly matBottomSheetRef: MatBottomSheetRef<DialogConfirmComponent>|undefined,

		/** @ignore */
		@Optional() @Inject(MatDialogRef)
		private readonly matDialogRef: MatDialogRef<DialogConfirmComponent>|undefined,

		/** @see StringsService */
		public readonly stringsService: StringsService
	) {
		super();
	}
}
