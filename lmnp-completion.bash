_lmnp_completion()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # File completion handling for specific options
    case "${prev}" in
        -f|--file|--journal|--stock|--immo)
            compopt -o filenames 2>/dev/null
            mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
            return 0
            ;;
    esac

    # Commandes de niveau 1
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        opts="configurer journal bilan help"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    # Niveau 2 (Sous-commandes)
    local cmd="${COMP_WORDS[1]}"
    
    case "${cmd}" in
        configurer)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                opts="init immo vehicules blanchisserie"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi
            # Niveau 3 pour configurer
            local subcmd="${COMP_WORDS[2]}"
            case "${subcmd}" in
                vehicules)
                    opts="ajouter lister -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                blanchisserie)
                    if [[ ${COMP_CWORD} -eq 3 ]]; then
                        opts="ajouter lister -h --help"
                    else
                        opts="--nom-bien --conso-eau --prix-eau --conso-kwh --prix-kwh --prix-produit -h --help"
                    fi
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                init)
                    opts="--siren --annee --data-dir --journal --stock --immo -f --force -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                immo)
                    opts="--valeur --date --nom --terrain --gros-oeuvre --facade --installations --agencements -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
            esac
            ;; 
        journal)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                opts="saisir importer-airbnb analyser-facture trajets blanchisserie status migrer-hash"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi
            # Niveau 3 pour journal
            local subcmd="${COMP_WORDS[2]}"
            case "${subcmd}" in
                trajets)
                    opts="ajouter lister -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                blanchisserie)
                    opts="ajouter lister -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                saisir)
                    opts="-d --date -j --journal -l --libelle -r --ref -f --file -c --compte -s --sens -m --montant -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                importer-airbnb)
                    opts="-f --file --blanchisserie --dry-run -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                status)
                    opts="--full -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                migrer-hash)
                    opts="--year -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                analyser-facture)
                    if [[ "$cur" == -* ]]; then
                        opts="-t --type --amortize-duration --no-amortize -h --help"
                        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    else
                        compopt -o filenames 2>/dev/null
                        mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
                    fi
                    return 0
                    ;; 
            esac
            ;; 
        bilan)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                opts="cloturer liasse fec"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi

            # Niveau 3 pour bilan
            local subcmd="${COMP_WORDS[2]}"
            case "${subcmd}" in
                cloturer)
                    opts="--timestamp --timestamp-only --no-timestamp -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
                liasse|fec)
                    opts="--year -h --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
            esac
            ;; 
    esac
}

complete -F _lmnp_completion lmnp