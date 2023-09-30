#!/bin/sh
#--------------------------------------
# fcitx-config
#

export TEXTDOMAIN=fcitx

if which kdialog > /dev/null 2>&1; then
    message() {
        kdialog --msgbox "$1"
    }
    error() {
        kdialog --error "$1"
    }
elif which zenity > /dev/null 2>&1; then
    message() {
        zenity --info --text="$1"
    }
    error() {
        zenity --error --text="$1"
    }
else
    message() {
        echo "$1"
    }
    error() {
        echo "$1" >&2
    }
fi

if which gettext > /dev/null 2>&1; then
    _() {
        gettext "$@"
    }
else
    _() {
        echo "$@"
    }
fi



# from xdg-open

detectDE() {
    # see https://bugs.freedesktop.org/show_bug.cgi?id=34164
    unset GREP_OPTIONS

    if [ -n "${XDG_CURRENT_DESKTOP}" ]; then
      case "${XDG_CURRENT_DESKTOP}" in
         GNOME)
           DE=gnome;
           ;;
         KDE)
           DE=kde;
           ;;
         LXDE)
           DE=lxde;
           ;;
         XFCE)
           DE=xfce
      esac
    fi

    if [ x"$DE" = x"" ]; then
      # classic fallbacks
      if [ x"$KDE_FULL_SESSION" = x"true" ]; then DE=kde;
      elif xprop -root KDE_FULL_SESSION 2> /dev/null | grep ' = \"true\"$' > /dev/null 2>&1; then DE=kde;
      elif [ x"$GNOME_DESKTOP_SESSION_ID" != x"" ]; then DE=gnome;
      elif [ x"$MATE_DESKTOP_SESSION_ID" != x"" ]; then DE=mate;
      elif dbus-send --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.gnome.SessionManager > /dev/null 2>&1 ; then DE=gnome;
      elif xprop -root _DT_SAVE_MODE 2> /dev/null | grep ' = \"xfce4\"$' >/dev/null 2>&1; then DE=xfce;
      elif xprop -root 2> /dev/null | grep -i '^xfce_desktop_window' >/dev/null 2>&1; then DE=xfce
      fi
    fi

    if [ x"$DE" = x"" ]; then
      # fallback to checking $DESKTOP_SESSION
      case "$DESKTOP_SESSION" in
         gnome)
           DE=gnome;
           ;;
         LXDE|Lubuntu)
           DE=lxde;
           ;;
         xfce|xfce4|'Xfce Session')
           DE=xfce;
           ;;
      esac
    fi

    if [ x"$DE" = x"" ]; then
      # fallback to uname output for other platforms
      case "$(uname 2>/dev/null)" in
        Darwin)
          DE=darwin;
          ;;
      esac
    fi

    if [ x"$DE" = x"gnome" ]; then
      # gnome-default-applications-properties is only available in GNOME 2.x
      # but not in GNOME 3.x
      which gnome-default-applications-properties > /dev/null 2>&1  || DE="gnome3"
    fi
}

run_kde() {
    # The KDE_SESSION_VERSION environment variable allows us to run the correct
    # KDE executables in this script, even if KDE's major version number
    # is changed (ex: kcmshell4 for KDE4 vs kcmshell5 for KDE5).
    #
    # This KDE documentation describes the variable:
    # https://userbase.kde.org/KDE_System_Administration/Environment_Variables
    #
    # But just to make sure that this variable is working the way we expect
    # (on the current system), we can sanity check it by making sure it is
    # defined and numeric using the below if-statement.
    #
    # This technique for checking whether the variable is numeric or not
    # should be POSIX-shell compatible, and is explained here:
    # https://stackoverflow.com/a/2704760/1261963
    #
    # Additionally we allow '.', '+', and '-', as future-proofing in case the
    # version numbers ever get more complicated.
    unset _kde_version
    if [ -n "${KDE_SESSION_VERSION##*[!0-9.+-]*}" ]; then
        # KDE_SESSION_VERSION variable is available, use it.
        _kde_version="$KDE_SESSION_VERSION"
    else
        # Fallback: use `xprop` and hope for the best.
        # This might not work reliably because KDE doesn't always supply
        # the KDE_SESSION_VERSION property on the root window
        # (this probably no longer works on newer versions of KDE).
        # But it's better than nothing.

        # On a system that supports this, the output from the `xprop` command
        # will look something like this:
        #     "KDE_SESSION_VERSION(CARDINAL) = 5"
        #
        # We use an `awk` command to split on the '= ' part of that text and
        # retrieve the '5', and this establishes what KDE version the system
        # is running for the current session.
        _kde_version="$(xprop -root KDE_SESSION_VERSION 2>&1 | awk -F'[=][[:space:]]*' '{print $NF}')"

        # If the above command fails, then $_kde_version will be something like:
        #    "KDE_SESSION_VERSION:  no such atom on any window."
        # In that case, we want to clear _kde_version to indicate that
        # we couldn't retrieve the version number.
        # We do this by unsetting _kde_version if it isn't numeric.
        if [ -z "${_kde_version##*[!0-9.+-]*}" ]; then
            unset _kde_version
        fi
    fi

    # Error handling: if something goes wrong, we have the challenge of
    # explaining how a wee little missing version number can ruin everything.
    # We will do our best to provide a straightforward (layman's) explanation,
    # followed by providing any system details that could help an expert
    # pinpoint the root-cause more quickly.
    unset _kde_error
    if [ -z "$_kde_version" ]; then
        _script_name="$0"
        _kde_error="$(_ "You're currently running KDE, but the KDE version number could not be determined. This makes it impossible to run certain KDE commands that are needed to run the KCModule for fcitx. This could be caused by an incomplete or damaged KDE installation, a regression or bug in the $_script_name script, or some other unknown reason. Now the config file will be opened with the default text editor.")"

        _xprop_output="$(xprop -root KDE_SESSION_VERSION 2>&1)"
        if [ -z "$KDE_SESSION_VERSION" ]; then
            _kde_error="$_kde_error $(_ "Additional details: The KDE_SESSION_VERSION environment variable is empty or undefined, and an 'xprop' command did not find a KDE_SESSION_VERSION property on any windows. The output from 'xprop -root KDE_SESSION_VERSION 2>&1' is as follows: $_xprop_output")"
        else # if [ -z "${KDE_SESSION_VERSION##*[!0-9.+-]*}" ]; then
            _wrong_text="$KDE_SESSION_VERSION"
            _kde_error="$_kde_error $(_ "Additional details: The KDE_SESSION_VERSION environment variable is not a number (it is '$_wrong_text'), and an 'xprop' command did not find a KDE_SESSION_VERSION property on any windows. The output from 'xprop -root KDE_SESSION_VERSION 2>&1' is as follows: $_xprop_output")"
        #else
            # This branch should not be reachable.
        fi
        return 1
    fi

    # Now that we know the KDE version number, we can use it to select which
    # kcmshell command we will call.
    # Thus, $_kcmshellN will with expand to
    # `kcmshell4` for KDE4,
    # `kcmshell5` for KDE5,
    # or anything else for later versions of KDE.
    _kcmshellN="kcmshell${_kde_version}"

    # Search the output of `kcmshellN --list` for the `kcm_fcitx` module,
    # then execute the module.
    if ($_kcmshellN --list 2>/dev/null | grep ^kcm_fcitx > /dev/null 2>&1); then
        if [ x"$1" != x ]; then
            exec $_kcmshellN kcm_fcitx --args "$1"
        else
            exec $_kcmshellN kcm_fcitx
        fi
    else
        # Simpler error handling for the case where `kcmshellN` simply couldn't
        # find the module that we are looking for. This case is very likely to
        # be caused by neglecting to install the KCModule's package using
        # the distro's package manager.
        _kde_error="$(_ "You're currently running KDE, but KCModule for fcitx couldn't be found, the package name of this KCModule is usually kcm-fcitx or kde-config-fcitx. Now it will open config file with default text editor.")"
    fi
}

run_gtk() {
    if which fcitx-config-gtk > /dev/null 2>&1; then
        exec fcitx-config-gtk "$1"
    fi
}

run_gtk3() {
    if which fcitx-config-gtk3 > /dev/null 2>&1; then
        exec fcitx-config-gtk3 "$1"
    fi
}

run_xdg() {
	if [ -n "$_kde_error" ]; then
		message "$_kde_error"
	else
		message "$(_ "You're currently running Fcitx with GUI, but fcitx-configtool couldn't be found, the package name is usually fcitx-config-gtk, fcitx-config-gtk3 or fcitx-configtool. Now it will open config file with default text editor.")"
	fi

    if command="$(which xdg-open 2>/dev/null)"; then
        detect_im_addon $1
        if [ x"$filename" != x ]; then
            exec $command "$HOME/.config/fcitx/conf/$filename.config"
        else
            exec "$command" "$HOME/.config/fcitx/config"
        fi
    fi
}

_which_cmdline() {
    cmd="$(which "$1")" || return 1
    shift
    echo "$cmd $*"
}

detect_im_addon() {
    filename=$1
    addonname=
    if [ x"$filename" != x ]; then
        addonname=$(fcitx-remote -m $1 2>/dev/null)
        if [ "$?" != "0" ]; then
            filename=
        elif [ x"$addonname" != x ]; then
            filename=$addonname
        fi
    fi

    if [ ! -f "$HOME/.config/fcitx/conf/$filename.config" ]; then
        filename=
    fi
}

run_editor() {
    if command="$(_which_cmdline ${EDITOR} 2>/dev/null)" ||
        command="$(_which_cmdline ${VISUAL} 2>/dev/null)"; then
        detect_im_addon $1
        if [ x"$filename" != x ]; then
            exec $command "$HOME/.config/fcitx/conf/$filename.config"
        else
            exec $command "$HOME/.config/fcitx/config"
        fi
    fi
}

if [ ! -n "$DISPLAY" ] && [ ! -n "$WAYLAND_DISPLAY" ]; then
    run_editor "$1"
    echo 'Please run it under X, or set $EDITOR or $VISUAL' >&2
    exit 0
fi

detectDE

# even if we are not on KDE, we should still try kde, some wrongly
# configured kde desktop cannot be detected (usually missing xprop)
# and if kde one can work, so why not use it if gtk, gtk3 not work?
# xdg/editor is never a preferred solution
case "$DE" in
    kde)
        order="kde gtk3 gtk xdg editor"
        ;;
    *)
        order="gtk3 gtk kde xdg editor"
        ;;
esac

for cmd in $order; do
    run_${cmd} "$1"
done

echo 'Cannot find a command to run.' >&2
