import {Injectable} from '@angular/core';
import {BaseProvider} from '../base-provider';
import {IResolvable} from '../iresolvable';
import {ISessionService} from '../service-interfaces/isession.service';
import {resolvable} from '../util/wait';
import {SessionInitService} from './session-init.service';


/**
 * SessionInitService implementation for accounts.
 */
@Injectable()
export class AccountSessionInitService extends BaseProvider implements SessionInitService {
	/** @inheritDoc */
	public callType?: 'audio'|'video';

	/** @inheritDoc */
	public readonly ephemeral: boolean	= false;

	/** @inheritDoc */
	public readonly id: string			= '';

	/** @inheritDoc */
	public readonly sessionService: IResolvable<ISessionService>	= resolvable();

	/** @inheritDoc */
	public spawn () : AccountSessionInitService {
		return new AccountSessionInitService();
	}

	constructor () {
		super();
	}
}
