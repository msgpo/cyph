import {Injectable} from '@angular/core';
import {
	AccountUserPresence,
	AccountUserProfile,
	IAccountUserPresence,
	IAccountUserProfile
} from '../../proto';
import {User} from '../account/user';
import {DataURIProto} from '../protos';
import {util} from '../util';
import {AccountDatabaseService} from './crypto/account-database.service';


/**
 * Account user lookup service.
 */
@Injectable()
export class AccountUserLookupService {
	/** @ignore */
	private readonly userCache: Map<string, User>	= new Map<string, User>();

	/** Tries to to get user object for the specified username. */
	public async getUser (username: string) : Promise<User> {
		username	= username.toLowerCase();
		const url	= `users/${username}`;

		const user	= util.getOrSetDefault(this.userCache, username, () => new User(
			username,
			this.accountDatabaseService.watch(
				`${url}/avatar`,
				DataURIProto,
				true,
				true
			),
			this.accountDatabaseService.watch(
				`${url}/coverImage`,
				DataURIProto,
				true,
				true
			),
			this.accountDatabaseService.getAsyncValue<IAccountUserPresence>(
				`${url}/presence`,
				AccountUserPresence,
				true,
				true
			),
			this.accountDatabaseService.getAsyncValue<IAccountUserProfile>(
				`${url}/publicProfile`,
				AccountUserProfile,
				true,
				true
			)
		));

		await user.accountUserProfile.getValue();

		return user;
	}

	constructor (
		/** @ignore */
		private readonly accountDatabaseService: AccountDatabaseService
	) {}
}
