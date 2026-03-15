#!/bin/sh
set -eu

for f in "$0"; do :; done

perl examples/input/01-button.pl
perl examples/input/02-toggle.pl
perl examples/input/03-textfield.pl
perl examples/input/04-list.pl
perl examples/input/05-textviewport.pl
perl examples/input/06-fieldlist.pl
perl examples/input/10-yesno-dialog.pl
perl examples/input/11-menu-dialog.pl
perl examples/input/12-form-dialog.pl
perl examples/input/13-mixed-dialog.pl
perl examples/input/14-textfield-validation.pl
