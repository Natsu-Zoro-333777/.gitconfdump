# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
fastfetch
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=100000
SAVEHIST=100000
HISTFILESIZE=100000
setopt autocd extendedglob nomatch notify
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/vegapunk/.zshrc'

autoload -Uz compinit
compinit
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
source <(fzf --zsh) #FZF optimization
# End of lines added by compinstall
### Variables ###

export EDITOR="nvim"
export VISUAL="nvim"

#Various Ctrl+ functions

#Ctrl+Backspace
bindkey '^H' backward-kill-word
#Ctrl+Delete
bindkey '^[[3;5~' kill-word
#Ctrl+Left
bindkey '^[[1;5C' forward-word
#Ctrl+Right
bindkey '^[[1;5D' backward-word

#colored MAN pages
export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;33;44m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;1;32m'
export LESS_TERMCAP_mr=$'\e[7m'
export LESS_TERMCAP_mh=$'\e[2m'
export LESS_TERMCAP_ZN=$'\e[74m'
export LESS_TERMCAP_ZV=$'\e[75m'
export LESS_TERMCAP_ZO=$'\e[73m'
export LESS_TERMCAP_ZW=$'\e[75m'
export MANPAGER='less -R'
export MANROFFOPT="-c"

###### Aliases #######
alias ls='ls -lAFh'                         # Preferred 'ls' implementation
alias less='less -FSRXc'                    # Preferred 'less' implementation
alias wget='wget -c'                        # Preferred 'wget' implementation (resume download)
alias c='clear'                             # c:            Clear terminal display
alias path='echo -e ${PATH//:/\\n}'         # path:         Echo all executable Paths
alias show_options='shopt'                  # Show_options: display bash options settings
alias fix_stty='stty sane'                  # fix_stty:     Restore terminal settings when screwed up
alias fix_term='echo -e "\033c"'            # fix_term:     Reset the conosle.  Similar to the reset command
alias cic='bind "set completion-ignore-case on"' # cic:          Make tab-completion case-insensitive
alias numFiles='_omb_util_print $(ls -1 | wc -l)'       # numFiles:     Count of non-hidden files in current dir
alias make1mb='truncate -s 1m ./1MB.dat'     # make1mb:      Creates a file of 1mb size (all zeros)
alias make5mb='truncate -s 5m ./5MB.dat'     # make5mb:      Creates a file of 5mb size (all zeros)
alias make10mb='truncate -s 10m ./10MB.dat'  # make10mb:     Creates a file of 10mb size (all zeros)
alias qfind="find . -name "                 # qfind:    Quickly search for file
alias memHogsTop='top -l 1 -o rsize | head -20'
alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'
alias keybinds='cat ~/.config/ghostty/config.ghostty'
alias neofetch='fastfetch'

#   cpuHogs:  Find CPU hogs
#   -----------------------------------------------------
alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'

#   topForever:  Continual 'top' listing (every 10 seconds)
#   -----------------------------------------------------
alias topForever='top -l 9999999 -s 10 -o cpu'

#   ttop:  Recommended 'top' invocation to minimize resources
#   ------------------------------------------------------------
#       Taken from this macosxhints article
#       http://www.macosxhints.com/article.php?story=20060816123853639
#   ------------------------------------------------------------
alias ttop="top -R -F -s 10 -o rsize"



#   ---------------------------
#   4.  NETWORKING
#   ---------------------------

alias netCons='lsof -i'                         # netCons:      Show all open TCP/IP sockets
alias lsock='sudo lsof -i -P'                   # lsock:        Display open sockets
alias lsockU='sudo lsof -nP | grep UDP'         # lsockU:       Display only open UDP sockets
alias lsockT='sudo lsof -nP | grep TCP'         # lsockT:       Display only open TCP sockets
alias openPorts='sudo lsof -i | grep LISTEN'    # openPorts:    All listening connections
alias showBlocked='sudo ipfw list'              # showBlocked:  All ipfw rules inc/ blocked IPs


#   ---------------------------------------
#   5.  SYSTEMS OPERATIONS & INFORMATION
#   ---------------------------------------

alias mountReadWrite='mount -uw /'    # mountReadWrite:   For use when booted into single-user


#   ---------------------------------------
#   6.  DATE & TIME MANAGEMENT
#   ---------------------------------------

alias bdate="date '+%a, %b %d %Y %T %Z'"
alias cal3='cal -3'
alias da='date "+%Y-%m-%d %A    %T %Z"'
alias daysleft='_omb_util_print "There are $(($(date +%j -d"Dec 31, $(date +%Y)")-$(date +%j))) left in year $(date +%Y)."'
alias epochtime='date +%s'
alias mytime='date +%H:%M:%S'
alias secconvert='date -d@1234567890'
alias stamp='date "+%Y%m%d%a%H%M"'
alias timestamp='date "+%Y%m%dT%H%M%S"'
alias today='date +"%A, %B %-d, %Y"'
alias weeknum='date +%V'


#   ---------------------------------------
#   8.  WEB DEVELOPMENT
#   ---------------------------------------

alias editHosts='sudo edit /etc/hosts'                  # editHosts:        Edit /etc/hosts file


#   ---------------------------------------
#   9.  OTHER ALIASES
#   ---------------------------------------

# Aliases by Jacob Hrbek
# Outputs List of Loadable Modules (llm) for current kernel
alias llm="find /lib/modules/$(uname -r) -type f -name '*.ko*'"
# Used for piping to remote pastebin from cmdline to generate a url


###### End Aliases #######
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
