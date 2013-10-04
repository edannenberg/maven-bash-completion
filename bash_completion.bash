# where plugin config is stored, no trailing slash!
plugin_config_path=~/.bash_completion_maven.d 

[ -d $plugin_config_path ] || mkdir -p $plugin_config_path

function_exists()
{
	declare -F $1 > /dev/null
	return $?
}

function_exists _get_comp_words_by_ref ||
_get_comp_words_by_ref ()
{
    local exclude cur_ words_ cword_;
    if [ "$1" = "-n" ]; then
        exclude=$2;
        shift 2;
    fi;
    __git_reassemble_comp_words_by_ref "$exclude";
    cur_=${words_[cword_]};
    while [ $# -gt 0 ]; do
        case "$1" in
            cur)
                cur=$cur_
            ;;
            prev)
                prev=${words_[$cword_-1]}
            ;;
            words)
                words=("${words_[@]}")
            ;;
            cword)
                cword=$cword_
            ;;
        esac;
        shift;
    done
}

function_exists __ltrim_colon_completions ||
__ltrim_colon_completions()
{
	if [[ "$1" == *:* && "$COMP_WORDBREAKS" == *:* ]]; then
		# Remove colon-word prefix from COMPREPLY items
		local colon_word=${1%${1##*:}}
		local i=${#COMPREPLY[*]}
		while [[ $((--i)) -ge 0 ]]; do
			COMPREPLY[$i]=${COMPREPLY[$i]#"$colon_word"}
		done
	fi
}

_mvn()
{
    local cur prev
    COMPREPLY=()
    _get_comp_words_by_ref -n : cur prev

    local opts="-am|-amd|-B|-C|-c|-cpu|-D|-e|-emp|-ep|-f|-fae|-ff|-fn|-gs|-h|-l|-N|-npr|-npu|-nsu|-o|-P|-pl|-q|-rf|-s|-T|-t|-U|-up|-V|-v|-X"
    local long_opts="--also-make|--also-make-dependents|--batch-mode|--strict-checksums|--lax-checksums|--check-plugin-updates|--define|--errors|--encrypt-master-password|--encrypt-password|--file|--fail-at-end|--fail-fast|--fail-never|--global-settings|--help|--log-file|--non-recursive|--no-plugin-registry|--no-plugin-updates|--no-snapshot-updates|--offline|--activate-profiles|--projects|--quiet|--resume-from|--settings|--threads|--toolchains|--update-snapshots|--update-plugins|--show-version|--version|--debug"

    local common_clean_lifecycle="pre-clean|clean|post-clean"
    local common_default_lifecycle="validate|initialize|generate-sources|process-sources|generate-resources|process-resources|compile|process-classes|generate-test-sources|process-test-sources|generate-test-resources|process-test-resources|test-compile|process-test-classes|test|prepare-package|package|pre-integration-test|integration-test|post-integration-test|verify|install|deploy"
    local common_site_lifecycle="pre-site|site|post-site|site-deploy"
    local common_lifecycle_phases="${common_clean_lifecycle}|${common_default_lifecycle}|${common_site_lifecycle}"

    # this should probably not happen inside this function, though it has the nice side effect that new plugin configs get picked up instantly
    if [ ! -n "$(find ${plugin_config_path} -maxdepth 0 -empty)" ]; then for f in ${plugin_config_path}/*; do . $f; done; fi

    local common_plugins=`compgen -v | grep "^plugin_goals_.*" | sed 's/plugin_goals_//g' | tr '\n' '|'`
    local common_params=`compgen -v | grep "^plugin_goal_params_.*" | sed 's/plugin_goal_params_//g' | tr '\n' '|'`

    local options="-Dmaven.test.skip=true|-DskipTests|-DskipITs|-Dmaven.surefire.debug|-DenableCiProfile|-Dpmd.skip=true|-Dcheckstyle.skip=true|-Dtycho.mode=maven|-Dmaven.javadoc.skip=true|-Dgwt.compiler.skip"

    local profile_settings=`[ -e ~/.m2/settings.xml ] && grep -e "<profile>" -A 1 ~/.m2/settings.xml | grep -e "<id>.*</id>" | sed 's/.*<id>//' | sed 's/<\/id>.*//g' | tr '\n' '|' `
    local profile_pom=`[ -e pom.xml ] && grep -e "<profile>" -A 1 pom.xml | grep -e "<id>.*</id>" | sed 's/.*<id>//' | sed 's/<\/id>.*//g' | tr '\n' '|' `
    local profiles="${profile_settings}|${profile_pom}"
    local IFS=$'|\n'

    # todo: handling if more then one -D param needs completion
    # todo: should print = instead of whitespace as last char if a item gets completed
    if [[ ${cur} == -D* ]] ; then
        local goal
        local show_default=true
        for goal in $common_params; do
          local formated_prev=${prev/"-"/"_"}
          local formated_goal=${goal/"-"/"_"}
          if [[ ${formated_goal} == ${formated_prev/":"/"_"} ]]; then
            show_default=false
            var_name="plugin_goal_params_${formated_goal}"
            COMPREPLY=( $(compgen -W "${!var_name}" -S ' ' -- ${cur}) )
          fi
        done
        if $show_default; then
            COMPREPLY=( $(compgen -S ' ' -W "${options}" -- ${cur}) )
        fi

    elif [[ ${prev} == -P ]] ; then
      if [[ ${cur} == *,* ]] ; then
        COMPREPLY=( $(compgen -S ',' -W "${profiles}" -P "${cur%,*}," -- ${cur##*,}) )
      else
        COMPREPLY=( $(compgen -S ',' -W "${profiles}" -- ${cur}) )
      fi

    elif [[ ${cur} == --* ]] ; then
      COMPREPLY=( $(compgen -W "${long_opts}" -S ' ' -- ${cur}) )

    elif [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -S ' ' -- ${cur}) )

    elif [[ ${prev} == -pl ]] ; then
        if [[ ${cur} == *,* ]] ; then
            COMPREPLY=( $(compgen -d -S ',' -P "${cur%,*}," -- ${cur##*,}) )
        else
            COMPREPLY=( $(compgen -d -S ',' -- ${cur}) )
        fi

    elif [[ ${prev} == -rf || ${prev} == --resume-from ]] ; then
        COMPREPLY=( $(compgen -d -S ' ' -- ${cur}) )

    elif [[ ${cur} == *:* ]] ; then
        local plugin
        for plugin in $common_plugins; do
          if [[ ${cur} == ${plugin}:* ]]; then
            var_name="plugin_goals_${plugin}"
            COMPREPLY=( $(compgen -W "${!var_name}" -S ' ' -- ${cur}) )
          fi
        done

    else
        if echo "${common_lifecycle_phases}" | tr '|' '\n' | grep -q -e "^${cur}" ; then
          COMPREPLY=( $(compgen -S ' ' -W "${common_lifecycle_phases}" -- ${cur}) )
        elif echo "${common_plugins}" | tr '|' '\n' | grep -q -e "^${cur}"; then
          COMPREPLY=( $(compgen -S ':' -W "${common_plugins}" -- ${cur}) )
        fi
    fi

    __ltrim_colon_completions "$cur"
}

complete -o default -F _mvn -o nospace mvn
complete -o default -F _mvn -o nospace mvnDebug
