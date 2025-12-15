_lmnp_completion()
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Liste des commandes principales
    commands="init ajouter importer-airbnb importer-facture amortir cloturer liasse export-fec creer-immo help"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        return 0
    fi

    # Complétion spécifique par commande
    case "${prev}" in
        init)
            opts="--siren --annee --journal --stock --immo --force --help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        creer-immo)
            opts="--valeur --date --nom --terrain --gros-oeuvre --facade --installations --agencements --force --help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        ajouter)
            opts="--date --journal --libelle --ref --compte --montant --sens --help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        importer-airbnb)
            opts="--file --help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        importer-facture)
            opts="--type --help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        amortir|cloturer|liasse|export-fec)
            opts="--help"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        *)
            ;;
    esac
}

complete -F _lmnp_completion lmnp
