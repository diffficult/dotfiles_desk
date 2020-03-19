#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

#---pkg not found suggestion
source /usr/share/doc/pkgfile/command-not-found.bash

#---Auto CD 
shopt -s autocd

BROWSER=/usr/bin/chromium
EDITOR=/usr/bin/nano

#-------- External Files {{{

# load alias/functions that works with both zsh/bash
if [[ -f ~/.aliasrc ]]; then
    source ~/.aliasrc
fi

# Climate Completion
if [ -f /etc/bash_completion.d/climate_completion ]; then
        source /etc/bash_completion.d/climate_completion
fi

# find-the-command
# options, append noprompt, quite, su, install, info, list_files, list_files_paged
#if [ -f /usr/share/doc/find-the-command/ftc.zsh ]; then
#       source /usr/share/doc/find-the-command/ftc.zsh 
#fi


#}}} -----------------------


source /home/rx/.config/broot/launcher/bash/br
