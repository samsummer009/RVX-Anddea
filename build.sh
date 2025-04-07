#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob
trap "rm -rf temp/*tmp.* temp/*/*tmp.* temp/*-temporary-files; exit 130" INT

if [ "${1-}" = "clean" ]; then
	rm -rf temp build logs build.md
	exit 0
fi

source utils.sh
set_prebuilts

vtf() { if ! isoneof "${1}" "true" "false"; then abort "ERROR: '${1}' is not a valid option for '${2}': only true or false is allowed"; fi; }

# -- Main config --
toml_prep "${1:-config.toml}" || abort "could not find config file '${1:-config.toml}'\n\tUsage: $0 <config.toml>"
main_config_t=$(toml_get_table_main)
COMPRESSION_LEVEL=$(toml_get "$main_config_t" compression-level) || COMPRESSION_LEVEL="9"
if ! PARALLEL_JOBS=$(toml_get "$main_config_t" parallel-jobs); then
	if [ "$OS" = Android ]; then PARALLEL_JOBS=1; else PARALLEL_JOBS=$(nproc); fi
fi
REMOVE_RV_INTEGRATIONS_CHECKS=$(toml_get "$main_config_t" remove-rv-integrations-checks) || REMOVE_RV_INTEGRATIONS_CHECKS="true"
DEF_PATCHES_VER=$(toml_get "$main_config_t" patches-version) || DEF_PATCHES_VER="latest"
DEF_CLI_VER=$(toml_get "$main_config_t" cli-version) || DEF_CLI_VER="latest"
DEF_PATCHES_SRC=$(toml_get "$main_config_t" patches-source) || DEF_PATCHES_SRC="ReVanced/revanced-patches"
DEF_CLI_SRC=$(toml_get "$main_config_t" cli-source) || DEF_CLI_SRC="j-hc/revanced-cli"
DEF_RV_BRAND=$(toml_get "$main_config_t" rv-brand) || DEF_RV_BRAND="ReVanced"
mkdir -p "$TEMP_DIR" "$BUILD_DIR"

if [ "${2-}" = "--config-update" ]; then
	config_update
	exit 0
fi

: >build.md
ENABLE_MAGISK_UPDATE=$(toml_get "$main_config_t" enable-magisk-update) || ENABLE_MAGISK_UPDATE=true
if [ "$ENABLE_MAGISK_UPDATE" = true ] && [ -z "${GITHUB_REPOSITORY-}" ]; then
	pr "You are building locally. Magisk updates will not be enabled."
	ENABLE_MAGISK_UPDATE=false
fi
if ((COMPRESSION_LEVEL > 9)) || ((COMPRESSION_LEVEL < 0)); then abort "compression-level must be within 0-9"; fi

jq --version >/dev/null || abort "\`jq\` is not installed. install it with 'apt install jq' or equivalent"
java --version >/dev/null || abort "\`openjdk 17\` is not installed. install it with 'apt install openjdk-17-jre' or equivalent"
zip --version >/dev/null || abort "\`zip\` is not installed. install it with 'apt install zip' or equivalent"

rm -rf revanced-magisk/bin/*/tmp.*
if [ "$(echo "$TEMP_DIR"/*-rv/changelog.md)" ]; then
	: >"$TEMP_DIR"/*-rv/changelog.md || :
fi

mkdir -p ${MODULE_TEMPLATE_DIR}/bin/arm64 ${MODULE_TEMPLATE_DIR}/bin/arm ${MODULE_TEMPLATE_DIR}/bin/x86 ${MODULE_TEMPLATE_DIR}/bin/x64
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm64/cmpr" "https://github.com/peternmuller/cmpr/releases/latest/download/cmpr-arm64-v8a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm/cmpr" "https://github.com/peternmuller/cmpr/releases/latest/download/cmpr-armeabi-v7a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x86/cmpr" "https://github.com/peternmuller/cmpr/releases/latest/download/cmpr-x86"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x64/cmpr" "https://github.com/peternmuller/cmpr/releases/latest/download/cmpr-x86_64"

declare -A cliriplib
idx=0
for table_name in $(toml_get_table_names); do
	if [ -z "$table_name" ]; then continue; fi
	t=$(toml_get_table "$table_name")
	enabled=$(toml_get "$t" enabled) || enabled=true
	vtf "$enabled" "enabled"
	if [ "$enabled" = false ]; then continue; fi
	if ((idx >= PARALLEL_JOBS)); then
		wait -n
		idx=$((idx - 1))
	fi

	declare -A app_args
	patches_src=$(toml_get "$t" patches-source) || patches_src=$DEF_PATCHES_SRC
	patches_ver=$(toml_get "$t" patches-version) || patches_ver=$DEF_PATCHES_VER
	cli_src=$(toml_get "$t" cli-source) || cli_src=$DEF_CLI_SRC
	cli_ver=$(toml_get "$t" cli-version) || cli_ver=$DEF_CLI_VER

	if ! RVP="$(get_rv_prebuilts "$cli_src" "$cli_ver" "$patches_src" "$patches_ver")"; then
		abort "could not download rv prebuilts"
	fi
	read -r rv_cli_jar rv_patches_jar <<<"$RVP"
	app_args[cli]=$rv_cli_jar
	app_args[ptjar]=$rv_patches_jar
	if [[ -v cliriplib[${app_args[cli]}] ]]; then app_args[riplib]=${cliriplib[${app_args[cli]}]}; else
		if [[ $(java -jar "${app_args[cli]}" patch 2>&1) == *rip-lib* ]]; then
			cliriplib[${app_args[cli]}]=true
			app_args[riplib]=true
		else
			cliriplib[${app_args[cli]}]=false
			app_args[riplib]=false
		fi
	fi
	if [ "${app_args[riplib]}" = "true" ] && [ "$(toml_get "$t" riplib)" = "false" ]; then app_args[riplib]=false; fi
	app_args[rv_brand]=$(toml_get "$t" rv-brand) || app_args[rv_brand]=$DEF_RV_BRAND

	app_args[excluded_patches]=$(toml_get "$t" excluded-patches) || app_args[excluded_patches]=""
	if [ -n "${app_args[excluded_patches]}" ] && [[ ${app_args[excluded_patches]} != *'"'* ]]; then abort "patch names inside excluded-patches must be quoted"; fi
	app_args[included_patches]=$(toml_get "$t" included-patches) || app_args[included_patches]=""
	if [ -n "${app_args[included_patches]}" ] && [[ ${app_args[included_patches]} != *'"'* ]]; then abort "patch names inside included-patches must be quoted"; fi
	app_args[exclusive_patches]=$(toml_get "$t" exclusive-patches) && vtf "${app_args[exclusive_patches]}" "exclusive-patches" || app_args[exclusive_patches]=false
	app_args[version]=$(toml_get "$t" version) || app_args[version]="auto"
	app_args[app_name]=$(toml_get "$t" app-name) || app_args[app_name]=$table_name
	app_args[patcher_args]=$(toml_get "$t" patcher-args) || app_args[patcher_args]=""
	app_args[table]=$table_name
	app_args[build_mode]=$(toml_get "$t" build-mode) && {
		if ! isoneof "${app_args[build_mode]}" both apk module; then
			abort "ERROR: build-mode '${app_args[build_mode]}' is not a valid option for '${table_name}': only 'both', 'apk' or 'module' is allowed"
		fi
	} || app_args[build_mode]=apk
	app_args[uptodown_dlurl]=$(toml_get "$t" uptodown-dlurl) && {
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%/}
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%download}
		app_args[uptodown_dlurl]=${app_args[uptodown_dlurl]%/}
		app_args[dl_from]=uptodown
	} || app_args[uptodown_dlurl]=""
	app_args[apkmirror_dlurl]=$(toml_get "$t" apkmirror-dlurl) && {
		app_args[apkmirror_dlurl]=${app_args[apkmirror_dlurl]%/}
		app_args[dl_from]=apkmirror
	} || app_args[apkmirror_dlurl]=""
	app_args[archive_dlurl]=$(toml_get "$t" archive-dlurl) && {
		app_args[archive_dlurl]=${app_args[archive_dlurl]%/}
		app_args[dl_from]=archive
	} || app_args[archive_dlurl]=""
	if [ -z "${app_args[dl_from]-}" ]; then abort "ERROR: no 'apkmirror_dlurl', 'uptodown_dlurl' or 'archive_dlurl' option was set for '$table_name'."; fi
	app_args[arch]=$(toml_get "$t" arch) || app_args[arch]="all"
	if [ "${app_args[arch]}" != "both" ] && [ "${app_args[arch]}" != "all" ] && [[ ${app_args[arch]} != "arm64-v8a"* ]] && [[ ${app_args[arch]} != "arm-v7a"* ]]; then
		abort "wrong arch '${app_args[arch]}' for '$table_name'"
	fi

	app_args[include_stock]=$(toml_get "$t" include-stock) || app_args[include_stock]=true && vtf "${app_args[include_stock]}" "include-stock"
	app_args[dpi]=$(toml_get "$t" apkmirror-dpi) || app_args[dpi]="nodpi"
	table_name_f=${table_name,,}
	table_name_f=${table_name_f// /-}
	app_args[module_prop_name]=$(toml_get "$t" module-prop-name) || app_args[module_prop_name]="${table_name_f}-peternmuller"

	if [ "${app_args[arch]}" = both ]; then
		app_args[table]="$table_name (arm64-v8a)"
		app_args[arch]="arm64-v8a"
		module_prop_name_b=${app_args[module_prop_name]}
		app_args[module_prop_name]="${module_prop_name_b}-arm64"
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
		app_args[table]="$table_name (arm-v7a)"
		app_args[arch]="arm-v7a"
		app_args[module_prop_name]="${module_prop_name_b}-arm"
		if ((idx >= PARALLEL_JOBS)); then
			wait -n
			idx=$((idx - 1))
		fi
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
	else
		if [ "${app_args[arch]}" = "arm64-v8a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm64"
		elif [ "${app_args[arch]}" = "arm-v7a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm"
		fi
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
	fi
done
wait
rm -rf temp/tmp.*
if [ -z "$(ls -A1 "${BUILD_DIR}")" ]; then abort "All builds failed."; fi

log "\nInstall [ReVanced GmsCore](https://github.com/ReVanced/GmsCore/releases/latest) for non-root YouTube and YouTube Music APKs"
log "(Optional) Use [zygisk-detach](https://github.com/j-hc/zygisk-detach/releases/latest) to detach root ReVanced YouTube and YouTube Music from the Play Store\n"
log "$(cat "$TEMP_DIR"/*-rv/changelog.md)"

SKIPPED=$(cat "$TEMP_DIR"/skipped 2>/dev/null || :)
if [ -n "$SKIPPED" ]; then
	log "\nSkipped:"
	log "$SKIPPED"
fi

pr "Done"

build_rv() {
	eval "declare -A args=${1#*=}"
	local version="" pkg_name=""
	local mode_arg=${args[build_mode]} version_mode=${args[version]}
	local app_name=${args[app_name]}
	local app_name_l=${app_name,,}
	app_name_l=${app_name_l// /-}
	local table=${args[table]}
	local dl_from=${args[dl_from]}
	local arch=${args[arch]}
	local arch_f=""
	if [ "$arch" ] && [ "$arch" != "all" ]; then
		if [ "$arch" = "arm-v7a" ]; then
			arch_f=".armeabi-v7a"
		else
			arch_f=".${arch// /}"
		fi
	fi

	local p_patcher_args=()
	if [ "${args[excluded_patches]}" ]; then p_patcher_args+=("$(join_args "${args[excluded_patches]}" -d)"); fi
	if [ "${args[included_patches]}" ]; then p_patcher_args+=("$(join_args "${args[included_patches]}" -e)"); fi
	[ "${args[exclusive_patches]}" = true ] && p_patcher_args+=("--exclusive")

	local tried_dl=()
	for dl_p in archive apkmirror uptodown; do
		if [ -z "${args[${dl_p}_dlurl]}" ]; then continue; fi
		if ! get_${dl_p}_resp "${args[${dl_p}_dlurl]}" || ! pkg_name=$(get_"${dl_p}"_pkg_name); then
			args[${dl_p}_dlurl]=""
			epr "ERROR: Could not find ${table} in ${dl_p}"
			continue
		fi
		tried_dl+=("$dl_p")
		dl_from=$dl_p
		break
	done
	if [ -z "$pkg_name" ]; then
		epr "empty pkg name, not building ${table}."
		return 0
	fi
	local list_patches
	list_patches=$(java -jar "$rv_cli_jar" list-patches "$rv_patches_jar" -f "$pkg_name" -v -p 2>&1)

	local get_latest_ver=false
	if [ "$version_mode" = auto ]; then
		if ! version=$(get_patch_last_supported_ver "$list_patches" "$pkg_name" \
			"${args[included_patches]}" "${args[excluded_patches]}" "${args[exclusive_patches]}"); then
			exit 1
		elif [ -z "$version" ]; then get_latest_ver=true; fi
	elif isoneof "$version_mode" latest beta; then
		get_latest_ver=true
		p_patcher_args+=("-f")
	else
		version=$version_mode
		p_patcher_args+=("-f")
	fi
	if [ $get_latest_ver = true ]; then
		if [ "$version_mode" = beta ]; then __AAV__="true"; else __AAV__="false"; fi
		pkgvers=$(get_"${dl_from}"_vers)
		version=$(get_highest_ver <<<"$pkgvers") || version=$(head -1 <<<"$pkgvers")
	fi
	if [ -z "$version" ]; then
		epr "empty version, not building ${table}."
		return 0
	fi

	if [ "$mode_arg" = module ]; then
		build_mode_arr=(module)
	elif [ "$mode_arg" = apk ]; then
		build_mode_arr=(apk)
	elif [ "$mode_arg" = both ]; then
		build_mode_arr=(apk module)
	fi

	pr "Choosing version '${version}' for ${table}"
	local version_f=${version// /}
	version_f=${version_f#v}
	local stock_apk="${TEMP_DIR}/${pkg_name}-${version_f}-${arch_f}.apk"
		if [ ! -f "$stock_apk" ]; then
		for dl_p in archive apkmirror uptodown; do
			if [ -z "${args[${dl_p}_dlurl]}" ]; then continue; fi
			pr "Downloading '${table}' from ${dl_p}"
			if ! isoneof $dl_p "${tried_dl[@]}"; then get_${dl_p}_resp "${args[${dl_p}_dlurl]}"; fi
			if ! dl_${dl_p} "${args[${dl_p}_dlurl]}" "$version" "$stock_apk" "$arch" "${args[dpi]}" "$get_latest_ver"; then
				epr "ERROR: Could not download '${table}' from ${dl_p} with version '${version}', arch '${arch}', dpi '${args[dpi]}'"
				continue
			fi
			break
		done
		if [ ! -f "$stock_apk" ]; then return 0; fi
	fi
	if ! OP=$(check_sig "$stock_apk" "$pkg_name" 2>&1) && ! grep -qFx "ERROR: Missing META-INF/MANIFEST.MF" <<<"$OP"; then
		abort "apk signature mismatch '$stock_apk': $OP"
	fi
	log "${table}: ${version}"

	local microg_patch
	microg_patch=$(grep "^Name: " <<<"$list_patches" | grep -i "gmscore\|microg" || :) microg_patch=${microg_patch#*: }
	if [ -n "$microg_patch" ] && [[ ${p_patcher_args[*]} =~ $microg_patch ]]; then
		epr "You cant include/exclude microg patch as that's done by rvmm builder automatically."
		p_patcher_args=("${p_patcher_args[@]//-[ei] ${microg_patch}/}")
	fi

	local patcher_args patched_apk build_mode
	local rv_brand_f=${args[rv_brand],,}
	rv_brand_f=${rv_brand_f// /-}
	if [ "${args[patcher_args]}" ]; then p_patcher_args+=("${args[patcher_args]}"); fi
	for build_mode in "${build_mode_arr[@]}"; do
		patcher_args=("${p_patcher_args[@]}")
		pr "Building '${table}' in '$build_mode' mode"
		if [ -n "$microg_patch" ]; then
			if [[ "$table" == *"YouTube-Music"* ]]; then
				patched_apk="${TEMP_DIR}/${app_name}-RVX-${version_f}-${build_mode}-temporary-files.apk"
			elif [[ "$table" == *"YouTube-Monet"* ]]; then
				patched_apk="${TEMP_DIR}/${app_name}-OG-Monet-RVX-${version_f}-${build_mode}-temporary-files.apk"
			else
				patched_apk="${TEMP_DIR}/${app_name}-OG-RVX-${version_f}-${build_mode}-temporary-files.apk"
			fi
		else
			if [[ "$table" == *"YouTube-Music"* ]]; then
				patched_apk="${TEMP_DIR}/${app_name}-RVX-${version_f}-temporary-files.apk"
			elif [[ "$table" == *"YouTube-Monet"* ]]; then
				patched_apk="${TEMP_DIR}/${app_name}-OG-Monet-RVX-${version_f}-temporary-files.apk"
			else
				patched_apk="${TEMP_DIR}/${app_name}-OG-RVX-${version_f}-temporary-files.apk"
			fi
		fi
		if [ -n "$microg_patch" ]; then
			if [ "$build_mode" = apk ]; then
				patcher_args+=("-e \"${microg_patch}\"")
			elif [ "$build_mode" = module ]; then
				patcher_args+=("-d \"${microg_patch}\"")
			fi
		fi

		# Handle custom branding patches
		local branding_patch
		if [[ "$table" == *"YouTube"* ]]; then
			if [[ "$table" == *"Music"* ]]; then
				branding_patch="Custom branding name for YouTube Music"
			else
				branding_patch="Custom branding name for YouTube"
			fi
			if [ "$build_mode" = apk ]; then
				patcher_args+=("-e \"${branding_patch}\"")
			elif [ "$build_mode" = module ]; then
				patcher_args+=("-d \"${branding_patch}\"")
			fi
		fi

		if [ "${args[riplib]}" = true ]; then
			patcher_args+=("--rip-lib x86_64 --rip-lib x86")
			if [ "$build_mode" = module ]; then
				patcher_args+=("--rip-lib arm64-v8a --rip-lib armeabi-v7a --unsigned")
			else
				if [ "$arch" = "arm64-v8a" ]; then
					patcher_args+=("--rip-lib armeabi-v7a")
				elif [ "$arch" = "arm-v7a" ]; then
					patcher_args+=("--rip-lib arm64-v8a")
				fi
			fi
		fi
		if [ "${NORB:-}" != true ] || [ ! -f "$patched_apk" ]; then
			if ! patch_apk "$stock_apk" "$patched_apk" "${patcher_args[*]}" "${args[cli]}" "${args[ptjar]}"; then
				epr "Building '${table}' failed!"
				return 0
			fi
		fi
		if [ "$build_mode" = apk ]; then
			if [[ "$table" == *"YouTube-Music"* ]]; then
				local apk_output="${BUILD_DIR}/${app_name}-RVX-${version_f}${arch_f}.apk"
			elif [[ "$table" == *"YouTube-Monet"* ]]; then
				local apk_output="${BUILD_DIR}/YouTube-OG-Monet-RVX-${version_f}${arch_f}.apk"
			else
				local apk_output="${BUILD_DIR}/${app_name}-OG-RVX-${version_f}${arch_f}.apk"
			fi
			mv -f "$patched_apk" "$apk_output"
			pr "Built ${table} (non-root): '${apk_output}'"
			continue
		fi
		local base_template
		base_template=$(mktemp -d -p "$TEMP_DIR")
		cp -a $MODULE_TEMPLATE_DIR/. "$base_template"
		local upj="${table,,}-update.json"

		module_config "$base_template" "$pkg_name" "$version" "$arch"

		local rv_patches_ver="${rv_patches_jar##*-}"
		module_prop \
			"${args[module_prop_name]}" \
			"${app_name} ${args[rv_brand]}" \
			"${version} (patches: ${rv_patches_ver%%.rvp})" \
			"${app_name} ${args[rv_brand]} Magisk module" \
			"https://raw.githubusercontent.com/${GITHUB_REPOSITORY-}/update/${upj}" \
			"$base_template"

		if [[ "$table" == *"YouTube-Music"* ]]; then
			local module_output="${app_name}-RVX-${version_f}${arch_f}.zip"
		elif [[ "$table" == *"YouTube-Monet"* ]]; then
			local module_output="YouTube-OG-Monet-RVX-${version_f}${arch_f}.zip"
		else
			local module_output="${app_name}-OG-RVX-${version_f}${arch_f}.zip"
		fi
		pr "Packing module ${table}"
		cp -f "$patched_apk" "${base_template}/base.apk"
		if [ "${args[include_stock]}" = true ]; then cp -f "$stock_apk" "${base_template}/${pkg_name}.apk"; fi
		pushd >/dev/null "$base_template" || abort "Module template dir not found"
		zip -"$COMPRESSION_LEVEL" -FSqr "${CWD}/${BUILD_DIR}/${module_output}" .
		popd >/dev/null || :
		pr "Built ${table} (root): '${BUILD_DIR}/${module_output}'"
	done
}
