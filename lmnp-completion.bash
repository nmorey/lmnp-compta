_lmnp_completion()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

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
                    opts="ajouter lister"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                blanchisserie)
                    opts="ajouter lister"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                init)
                    opts="--siren --annee --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                immo)
                    opts="--nom --valeur --date --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
            esac
            ;; 
        journal)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                opts="saisir importer-airbnb analyser-facture trajets blanchisserie status"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi
            # Niveau 3 pour journal
            local subcmd="${COMP_WORDS[2]}"
            case "${subcmd}" in
                trajets)
                    opts="ajouter lister"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                blanchisserie)
                    opts="ajouter lister"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                saisir)
                    opts="--date --journal --libelle --montant --compte --sens"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;; 
                analyser-facture)
                    opts="--type --help"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    # Fichiers PDF
                    local IFS=$'\n'
                    compopt -o filenames 2>/dev/null
                    COMPREPLY+=( $(compgen -f -- "${cur}") )
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
                liasse|fec)
                    opts="--year"
                    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                    return 0
                    ;;
            esac
            ;; 
    esac
}

complete -F _lmnp_completion lmnp