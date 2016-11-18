#!/bin/bash

cd $(cd "$(dirname "$0")"; pwd)/..
dir="$(pwd)"


watch=''
test=''
simple=''
cloneworkingdir=''

if [ "${1}" == '--watch' ] ; then
	watch=true
	shift
fi
if [ "${1}" == '--test' ] ; then
	test=true
	shift
fi
if [ "${1}" == '--simple' ] ; then
	simple=true
	shift
fi
if [ ! -d ~/.build ] ; then
	cloneworkingdir=true
	shift
fi

if [ "${cloneworkingdir}" ] ; then
	mkdir ~/.build
	cp -rf * ~/.build/
	cd ~/.build/
fi

tsfiles="$( \
	{ \
		find . -name '*.html' -not \( \
			-path './.build/*' \
			-or -path './websign/*' \
			-or -path '*/lib/*' \
		\) -exec cat {} \; | \
		grep -oP "src=(['\"])/js/.*?\1" & \
		grep -roP "importScripts\((['\"])/js/.*\1\)" shared/js & \
		echo cyph/analytics; \
	} | \
		perl -pe "s/.*?['\"]\/js\/(.*)\.js.*/\1/g" | \
		sort | \
		uniq | \
		grep -v 'Binary file' | \
		tr ' ' '\n' \
)"

cd shared

scssfiles="$(find css -name '*.scss' | grep -v bourbon/ | perl -pe 's/(.*)\.scss/\1/g' | tr '\n' ' ')"


output=''

modulename () {
	m="$(echo ${1} | perl -pe 's/.*\/([^\/]+)$/\u$1/')"
	classM="$(grep -oiP "class\s+${m}" ${1}.ts | perl -pe 's/class\s+//')"

	if [ "${classM}" ] ; then
		echo "${classM}"
	else
		echo "${m}"
	fi
}

tsbuild () {
	node -e "
		const tsconfig	= JSON.parse(
			fs.readFileSync('tsconfig.json').toString()
		);

		tsconfig.files	= 'preload/global ${*}'.
			trim().
			split(/\s+/).
			map(f => f + '.ts')
		;

		fs.writeFileSync(
			'tsconfig.json',
			JSON.stringify(tsconfig)
		);
	"

	output="${output}$(ngc -p . 2>&1)"
}

compile () {
	cd "${dir}/shared"

	if [ "${cloneworkingdir}" ] ; then
		find . -mindepth 1 -maxdepth 1 -type d -not -name lib -exec bash -c '
			rm -rf ~/.build/shared/{} 2> /dev/null;
			cp -rf {} ~/.build/shared/;
		' \;
		cd ~/.build/shared
	fi

	for f in $scssfiles ; do
		command="scss -Icss ${f}.scss ${dir}/shared/${f}.css"
		if [ "${watch}" ] ; then
			$command &
		else
			output="${output}$($command 2>&1)"
		fi
	done

	cd js

	if [ ! "${simple}" -o ! "${test}" ] ; then
		for f in $tsfiles ; do
			node -e "
				const resolveReferences	= f => {
					const path		= fs.realpathSync(f);
					const parent	= path.split('/').slice(0, -1).join('/');

					return fs.readFileSync(path).toString().trim().replace(
						/\/\/\/ <reference path=\"(.*)\".*/g,
						(ref, sub) => sub.match(/\.d\.ts\$/) ?
							ref :
							\`export const _\${crypto.randomBytes(4).toString('hex')} = (() => {
								\${resolveReferences(parent + '/' + sub)}
							})();\`
					);
				};

				fs.writeFileSync(
					'${f}.ts',
					resolveReferences('${f}.ts')
				);
			"
		done
	fi

	tsbuild $(echo "$tsfiles" | grep -vP '/main$')

	for f in $(echo "$tsfiles" | grep -P '/main$') ; do
		tsbuild $f
		sed -i 's|./appmodule|./appmodule.ngfactory|g' "${f}.ts"
		sed -i 's|AppModule|AppModuleNgFactory|g' "${f}.ts"
		sed -i 's|bootstrapModule|bootstrapModuleFactory|g' "${f}.ts"
		tsbuild $f
	done

	if [ ! "${simple}" -o ! "${test}" ] ; then
		for f in $tsfiles ; do
			webpack \
				--output-library-target var \
				--output-library "$(modulename $f)" \
				$f.js \
				$f.js.tmp
		done
		for f in $tsfiles ; do
			m="$(modulename $f)"

			{
				cat preload/global.js;
				cat $f.js.tmp | sed "0,/var ${m} =/s||self.${m} =|";
				echo "${m} = ${m}.${m} || ${m};";
			} | \
				if [ "${watch}" ] ; then cat - ; else babel --presets es2015 --compact false ; fi | \
				sed 's|use strict||g' \
			> "${dir}/shared/js/${f}.js"

			rm $f.js.tmp
		done

		for js in $(find . -name '*.js') ; do
			delete=true
			for f in $tsfiles ; do
				if [ "${js}" == "./${f}.js" ] ; then
					delete=''
				fi
			done
			if [ "${delete}" ] ; then
				rm "${js}"
			fi
		done
	fi
}

litedeploy () {
	rm -rf ~/.litedeploy 2> /dev/null
	mkdir ~/.litedeploy
	cp -rf ~/.build/default ~/.build/cyph.im ~/.litedeploy
	cd ~/.litedeploy

	version="lite-${username}-${branch}"
	deployedBackend="https://${version}-dot-cyphme.appspot.com"
	localBackend='${locationData.protocol}//${locationData.hostname}:42000'

	sed -i "s|staging|${version}|g" default/config.go
	sed -i "s|${localBackend}|${deployedBackend}|g" cyph.im/js/cyph.im/main.js
	cat cyph.im/cyph-im.yaml | perl -pe 's/(- url: .*)/\1\n  login: admin/g' > yaml.new
	mv yaml.new cyph.im/cyph-im.yaml

	gcloud app deploy --quiet --no-promote --project cyphme --version $version */*.yaml
}

if [ "${watch}" ] ; then
	eval "$(${dir}/commands/getgitdata.sh)"

	while true ; do
		sleep 2m

		if [ -f ~/.litedeploy.tmp ] ; then
			echo -e "\n\n\nDeploying to lite env\n\n"
			litedeploy
			rm ~/.litedeploy.tmp 2> /dev/null
			echo -e "\n\n\nFinished deploying\n\n"
		fi

		sleep 13m
	done &

	while true ; do
		rm ~/.litedeploy.tmp 2> /dev/null

		start="$(date +%s)"
		echo -e '\n\n\nBuilding JS/CSS\n\n'
		output=''
		compile
		echo -e "${output}\n\n\nFinished building JS/CSS ($(expr $(date +%s) - $start)s)\n\n"

		touch ~/.litedeploy.tmp

		cd "${dir}/shared"
		inotifywait -r --exclude '(node_modules|sed.*|.*\.(html|css|js|map|tmp))$' css js
	done
else
	compile
fi

echo -e "${output}"
exit ${#output}
