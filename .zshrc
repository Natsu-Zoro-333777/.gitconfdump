# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL10K_INSTANT_PROMPT=quiet

# Defined up here because the greeting below runs before the alias section.
# `function` is required: a plain `today()` is alias-expanded, and a parse
# error there aborts the rest of this file.
(( ${+aliases[today]} )) && unalias today
(( ${+aliases[daysleft]} )) && unalias daysleft
function today {
  date +"%A, %B %-d, %Y"
}
function daysleft {
  local year_end today_n
  year_end=$(date -d "Dec 31" +%j)
  today_n=$(date +%j)
  # 10# forces base 10. GNU date zero-pads %j, and 08/09 are invalid octal.
  print -r -- "There are $((10#$year_end - 10#$today_n)) days left in year $(date +%Y)."
}

fastfetch
daysleft
today
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

# Grok completions must be on fpath before this compinit. The installer
# block below calls `compinit -C`, which does not rescan for new files.
fpath=("$HOME/.grok/completions/zsh" $fpath)

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
alias ls='ls -lAFh --color=auto'            # Preferred 'ls' implementation
alias less='less -FSRXc'                    # Preferred 'less' implementation
alias wget='wget -c'                        # Preferred 'wget' implementation (resume download)
alias c='clear'                             # c:            Clear terminal display
alias path='print -l $path'                 # path:         One PATH entry per line
alias show_options='setopt'                 # show_options: display zsh options
alias fix_stty='stty sane'                  # fix_stty:     Restore terminal settings when screwed up
alias fix_term='printf "\033c"'             # fix_term:     Reset the console. Similar to reset
function cic {                               # cic:          Make tab-completion case-insensitive
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
  print -r -- 'Completion is case-insensitive for this shell.'
}
function numFiles {                          # numFiles:     Count of non-hidden files in the current directory
  local n
  n=$(command ls -1 | wc -l)
  print -r -- ${n//[[:space:]]/}
}
alias make1mb='truncate -s 1m ./1MB.dat'     # make1mb:      Creates a file of 1mb size (all zeros)
alias make5mb='truncate -s 5m ./5MB.dat'     # make5mb:      Creates a file of 5mb size (all zeros)
alias make10mb='truncate -s 10m ./10MB.dat'  # make10mb:     Creates a file of 10mb size (all zeros)
function qfind {                             # qfind:        Find by exact name under the current directory
  if (( $# == 0 )); then
    print -u2 'usage: qfind name'
    return 1
  fi
  command find . -name "$1"
}
alias memHogsTop='top -b -n 1 -o RES -w 200 | head -n 20'
alias memHogsPs='ps -eo pid,stat,vsz,rss,time,cmd --sort=-rss | head -n 11'
alias keybinds='cat ~/.config/ghostty/config.ghostty'
alias neofetch='fastfetch'

alias cpu_hogs='ps -eo pid,stat,%cpu,time,cmd --sort=-%cpu | head -n 11'

# Refresh every 10 seconds, sorted by CPU.
alias topForever='top -d 10 -o %CPU'

# Refresh every 10 seconds, sorted by resident memory.
alias ttop='top -d 10 -o RES'

alias netCons='lsof -nP -i'                      # netCons:      Show all open TCP/IP sockets
alias lsock='sudo lsof -nP -i'                   # lsock:        Display open sockets
alias lsockU='sudo lsof -nP -iUDP'               # lsockU:       Display only open UDP sockets
alias lsockT='sudo lsof -nP -iTCP'               # lsockT:       Display only open TCP sockets
alias openPorts='sudo lsof -nP -iTCP -sTCP:LISTEN' # openPorts:  Listening TCP ports
alias showBlocked='sudo nft list ruleset'        # showBlocked:  nftables ruleset

alias mountReadWrite='sudo mount -o remount,rw /' # mountReadWrite: Remount / read-write

alias bdate="date '+%a, %b %d %Y %T %Z'"
alias cal3='cal -3'
alias da='date "+%Y-%m-%d %A    %T %Z"'
# today and daysleft are functions at the top of this file.
alias epochtime='date +%s'
alias mytime='date +%H:%M:%S'
function secconvert { date -d "@${1:-1234567890}"; } # secconvert [epoch]
alias stamp='date "+%Y%m%d%a%H%M"'
alias timestamp='date "+%Y%m%dT%H%M%S"'
alias weeknum='date +%V'

alias editHosts='sudoedit /etc/hosts'            # editHosts:    Edit /etc/hosts

function llm {                               # llm:          Modules for the running kernel
  command find "/lib/modules/$(uname -r)" -type f -name '*.ko*'
}

###### End Aliases #######
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
