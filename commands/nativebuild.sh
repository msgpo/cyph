#!/bin/bash


cd $(cd "$(dirname "$0")" ; pwd)/..
dir="$PWD"


plugins="$(cat shared/js/native/plugins.list)"

externals="{
	$(for plugin in ${plugins} ; do echo "
		'${plugin}': \"require('${plugin}')\",
	" ; done)
	'_stream_duplex': 'undefined',
	'_stream_writable': 'undefined',
	'faye-websocket': '{Client: self.WebSocket}',
	'jquery': 'undefined',
	'libsodium': 'self.sodium',
	'simplewebrtc': '{}',
	'request': 'undefined',
	'rsvp': 'undefined'
}"

cd
tns create cyph --ng --appid com.cyph.app || exit 1
cd cyph

for plugin in ${plugins} ; do tns plugin add ${plugin} < /dev/null || exit 1 ; done
mv node_modules node_modules.old
ln -s /node_modules node_modules

mkdir -p tmp/app
mv app/App_Resources tmp/app/
cd tmp

mv ../node_modules ./
cp -rf ${dir}/shared/js/typings ./
cp -rf ${dir}/shared/js/native/* app/
cp -rf ${dir}/shared/css/native app/css
mv app/css/app.scss app/
cp -r ${dir}/shared/css/* app/css/
cp -r ${dir}/shared/css/* app/
rm -rf app/native app/css/native
cp -rf ${dir}/shared/templates/native app/templates

rm -rf app/js
mkdir -p app/js/cyph.ws app/js/standalone
cp ${dir}/shared/js/standalone/global.ts app/js/standalone/
cp -rf ${dir}/shared/js/cyph.ws/enums app/js/cyph.ws/
cp -rf ${dir}/shared/js/cyph app/js/
cp -rf ${dir}/shared/js/environments app/js/
cp -rf ${dir}/shared/js/typings app/js/

for module in cyph-app cyph-common ; do
	modulePath="app/js/cyph/modules/${module}.module.ts"
	cat "${modulePath}" |
		grep -v CyphWebModule |
		sed 's|NgModule}|NgModule, NO_ERRORS_SCHEMA}|g' |
		sed 's|exports:|schemas: [NO_ERRORS_SCHEMA], exports:|g' \
	> "${modulePath}.new"
	mv "${modulePath}.new" "${modulePath}"
done

grep -rl "@import '~" app | xargs -I% sed -i "s|@import '~|@import '/node_modules/|g" %
grep -rl "importScripts('/assets/" app |
	xargs -I% sed -i "s|importScripts('/assets/|importScripts('/|g" %

find app -type f -name '*.scss' -exec bash -c '
	scss "{}" "$(echo "{}" | sed "s/\.scss$/.css/")"
' \;
cp -rf app/css app/templates app/js/

find app -type f -name '*.ts' -exec sed -i "s|\.scss'|\.css'|g" {} \;

importedTsfiles="app/js/cyph/crypto/native-web-crypto-polyfill $(
	grep -roP "importScripts\((['\"])/js/.*\1\)" app |
		perl -pe "s/.*?['\"]\/js\/(.*)\.js.*/app\/js\/\1/g" |
		sort |
		uniq |
		tr '\n' ' '
)"

node -e "
	const tsconfig	= JSON.parse(
		fs.readFileSync('${dir}/shared/js/tsconfig.json').toString().
			split('\n').
			filter(s => s.trim()[0] !== '/').
			join('\n')
	);

	tsconfig.compilerOptions.rootDir	= '.';
	tsconfig.compilerOptions.outDir		= '.';

	tsconfig.compilerOptions.paths		= undefined;

	tsconfig.files	= 'typings/index.d ${importedTsfiles}'.
		trim().
		split(/\s+/).
		map(f => f + '.ts')
	;

	fs.writeFileSync('tsconfig.json', JSON.stringify(tsconfig));
"
tsc -p .
if (( $? )) ; then
	echo -e '\n\nFAIL\n\n'
	exit 1
fi
for f in ${importedTsfiles} ; do
	cat > "${f}.webpack.js" <<- EOM
		module.exports	= {
			entry: {
				app: './${f}'
			},
			externals: ${externals},
			output: {
				filename: '${f}.js',
				path: '${PWD}'
			}
		};
	EOM
	webpack --config "${f}.webpack.js"
	if (( $? )) ; then
		echo -e '\n\nFAIL\n\n'
		exit 1
	fi
done

node -e "
	const tsconfig	= JSON.parse(fs.readFileSync('tsconfig.json').toString());
	tsconfig.compilerOptions.rootDir	= undefined;
	tsconfig.files	= ['app/main.ts'];
	fs.writeFileSync('tsconfig.json', JSON.stringify(tsconfig));
"
sed -i 's|/platform|/platform-static|g' app/main.ts
sed -i 's|platformNativeScriptDynamic|platformNativeScript|g' app/main.ts
./node_modules/@angular/compiler-cli/src/main.js -p .
if (( $? )) ; then
	echo -e '\n\nFAIL\n\n'
	exit 1
fi
sed -i 's|\./app.module|\./app.module.ngfactory|g' app/main.ts
sed -i 's|AppModule|AppModuleNgFactory|g' app/main.ts
sed -i 's|bootstrapModule|bootstrapModuleFactory|g' app/main.ts


for platform in android ios ; do
	cat > webpack.js <<- EOM
		const AotPlugin	= require('@ngtools/webpack').AotPlugin;
		const webpack	= require('webpack');

		module.exports	= {
			entry: {
				app: './app/main.ts'
			},
			externals: ${externals},
			module: {
				rules: [
					{
						test: /\.html$/,
						use: [{loader: 'raw-loader'}]
					},
					{
						test: /\.css$/,
						use: [{loader: 'raw-loader'}]
					},
					{
						test: /\.ts$/,
						use: [{loader: '@ngtools/webpack'}]
					}
				]
			},
			node: {
				http: false,
				timers: false,
				setImmediate: false
			},
			output: {
				filename: 'app/main.${platform}.js',
				path: '${PWD}'
			},
			plugins: [
				new AotPlugin({
					entryModule: '${PWD}/app/app.module#AppModule',
					tsConfigPath: './tsconfig.json'
				})
			],
			resolve: {
				extensions: [
					'.ts',
					'.js',
					'.html',
					'.css',
					'.${platform}.ts',
					'.${platform}.js',
					'.${platform}.html',
					'.${platform}.css'
				],
				modules: [
					'node_modules/tns-core-modules',
					'node_modules'
				]
			}
		};
	EOM

	webpack --config webpack.js
	if (( $? )) ; then
		echo -e '\n\nFAIL\n\n'
		exit 2
	fi

	cp node_modules/core-js/client/shim.js main.${platform}.js
	echo >> main.${platform}.js
	cat app/js/standalone/global.js >> main.${platform}.js
	echo >> main.${platform}.js
	cat app/js/cyph/crypto/native-web-crypto-polyfill.js >> main.${platform}.js
	node -e 'console.log(`
		(function () {
			var exports	= undefined;
			var print	= function (s) { console.log(s); };
			importScripts("/node_modules/libsodium/dist/browsers-sumo/combined/sodium.js");
		})();

		self.translations = ${JSON.stringify(
			child_process.spawnSync("find", [
				"../translations",
				"-name",
				"*.json"
			]).stdout.toString().
				split("\n").
				filter(s => s).
				map(file => ({
					key: file.split("/").slice(-1)[0].split(".")[0],
					value: JSON.parse(fs.readFileSync(file).toString())
				})).
				reduce((translations, o) => {
					translations[o.key]	= o.value;
					return translations;
				}, {})
		)};
	`)' >> main.${platform}.js
	cat app/main.${platform}.js >> main.${platform}.js

	sed -i "s|importScripts('/lib/js/|importScripts('/|g" main.${platform}.js
	sed -i "s|importScripts('/js/|importScripts('/app/js/|g" main.${platform}.js
	/cyph/commands/websign/threadpack.js main.${platform}.js
done

cd ..
rm -rf app hooks/*/nativescript-dev-typescript.js
mkdir app
mv tmp/main.*.js tmp/app/App_Resources tmp/app/app.css tmp/app/package.json app/
mv node_modules.old node_modules
rm -rf tmp

cd
rm -rf ${dir}/.nativebuild 2> /dev/null
mv cyph ${dir}/.nativebuild

echo -e '\n\nPASS\n\n'
