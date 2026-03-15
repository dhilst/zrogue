#!/usr/bin/env bash
set -u

cd "$(dirname "$0")" || exit 1

tmpdir="$(mktemp -d)"
cleanup() {
    if [ "$status" -eq 0 ]; then
        rm -rf "$tmpdir"
    else
        echo "Preserved transcripts in: $tmpdir"
    fi
}
trap cleanup EXIT

status=0
case_failed=0

keys_to_input() {
    local key_spec="$1"
    local output=""
    local token

    for token in $key_spec; do
        case "$token" in
            enter) output+=$'\n' ;;
            space) output+=" " ;;
            *) output+="$token" ;;
        esac
    done

    printf '%s' "$output"
}

assert_contains() {
    local file="$1"
    local needle="$2"

    if ! grep -Fq "$needle" "$file"; then
        echo "  ASSERT FAIL: missing '$needle'"
        status=1
        case_failed=1
    fi
}

assert_regex() {
    local file="$1"
    local pattern="$2"

    if ! grep -Eq "$pattern" "$file"; then
        echo "  ASSERT FAIL: regex '$pattern' did not match"
        status=1
        case_failed=1
    fi
}

run_case() {
    local example="$1"
    local key_spec="$2"
    local expected_exit="$3"
    local expected_action_exit="$4"
    local expected_phase="$5"
    local contains_checks="$6"
    local regex_checks="$7"
    local expected_file_output="$8"

    local in_file="$tmpdir/$example.keys"
    local transcript="$tmpdir/$example.transcript"
    local clean="$tmpdir/$example.clean"
    local output_file="$tmpdir/$example.output"
    local cmd
    local rc

    case_failed=0
    keys_to_input "$key_spec" > "$in_file"

    echo "==> $example"
    echo "  keys: $key_spec"

    cmd="perl \"$example\""
    if [ -n "$expected_file_output" ]; then
        cmd="perl \"$example\" -output \"$output_file\""
    fi

    perl -MTime::HiRes=usleep -e '
        my $path = shift @ARGV;
        open my $fh, "<", $path or die "open($path): $!";
        local $/;
        my $data = <$fh>;
        close $fh;
        for my $ch (split //, $data) {
            print $ch;
            usleep 80_000;
        }
    ' "$in_file" | script -qefc "$cmd" "$transcript" >/dev/null 2>&1
    rc=$?
    tr -d '\r' < "$transcript" > "$clean"
    echo "  exit=$rc"

    if [ "$rc" -ne "$expected_exit" ]; then
        echo "  ASSERT FAIL: expected exit=$expected_exit"
        status=1
        case_failed=1
    fi

    assert_contains "$clean" "phase=$expected_phase"
    assert_contains "$clean" "exit_code=$expected_action_exit"

    local check
    IFS=';' read -r -a checks <<< "$contains_checks"
    for check in "${checks[@]}"; do
        [ -z "$check" ] && continue
        assert_contains "$clean" "$check"
    done

    IFS=';' read -r -a checks <<< "$regex_checks"
    for check in "${checks[@]}"; do
        [ -z "$check" ] && continue
        assert_regex "$clean" "$check"
    done

    if [ -n "$expected_file_output" ]; then
        if [ ! -f "$output_file" ]; then
            echo "  ASSERT FAIL: expected output file missing: $output_file"
            status=1
            case_failed=1
        else
            local actual_output
            actual_output="$(cat "$output_file")"
            if [ "$actual_output" != "$expected_file_output" ]; then
                echo "  ASSERT FAIL: output file mismatch"
                echo "  expected: $expected_file_output"
                echo "  actual:   $actual_output"
                status=1
                case_failed=1
            fi
        fi
    fi

    if [ "$case_failed" -ne 0 ]; then
        echo "  transcript: $clean"
    fi
    echo
}

# example | keys | process exit | action exit | phase | contains checks | regex checks | output-file
run_case "01-button-action.pl" "space" 0 0 "completed" "result.label=button-demo;stdout=;stderr=" "" ""
run_case "02-key-trigger.pl" "a" 0 0 "completed" "result.trigger=hotkey;stdout=;stderr=" "" ""
run_case "03-yesno-run.pl" "j space" 0 0 "completed" "result.choice=no;stdout=;stderr=" "" ""
run_case "04-menu-run.pl" "j J space" 0 0 "completed" "result.selection=Repair;stdout=;stderr=" "" ""
run_case "05-textfield-command.pl" "enter x y enter j space" 0 0 "completed" "result.command=deployxy;stdout=;stderr=" "" ""
run_case "06-list-target.pl" "j j J space" 0 0 "completed" "result.target=Charlie;stdout=;stderr=" "" ""
run_case "07-fieldlist-form.pl" "enter X enter J space" 0 0 "completed" "result.name=AdaX;stdout=;stderr=" "" ""
run_case "08-toggle-option.pl" "space j space" 0 0 "completed" "result.safe_mode=disabled;stdout=;stderr=" "" ""
run_case "09-buttonrow-progress.pl" "j space" 0 0 "completed" "result.mode=slow;stdout=;stderr=" "" ""
run_case "10-viewport-log.pl" "j J space" 0 0 "completed" "result.label=log;stdout=;stderr=" "" ""
run_case "11-mixed-pane.pl" "j j j J j space" 0 0 "completed" "result.target=Tower;stdout=;stderr=" "" ""
run_case "12-custom-keymap.pl" "l space" 0 0 "completed" "result.label=bravo;stdout=;stderr=" "" ""
run_case "13-runtime-setup.pl" "space" 0 0 "completed" "stdout=;stderr=" "^result\\.term=.+$" ""
run_case "14-success-exit.pl" "space" 0 0 "completed" "result.mode=success;result.ok=1;stdout=;stderr=" "" ""
run_case "15-failed-action.pl" "space" 3 0 "completed" "result.mode=fail;result.status=failed;stdout=;stderr=" "" ""
run_case "16-stderr-report.pl" "space" 0 0 "completed" "stderr=diagnostic:stderr" "" ""
run_case "17-stdout-report.pl" "space" 0 0 "completed" "stdout=;stderr=" "" "payload:stdout"
run_case "18-multi-step-progress.pl" "space" 0 0 "completed" "result.steps=5;stdout=;stderr=" "" ""
run_case "19-form-confirm.pl" "J space" 0 0 "completed" "result.name=Nova;stdout=;stderr=" "" ""
run_case "20-full-lifecycle.pl" "j space j j J j space" 0 0 "completed" "result.safe=no;stdout=;stderr=" "" "launch:ASH:Archive"
run_case "23-tabs-help-modal.pl" "space space j space" 0 0 "completed" "result.help_seen=1;result.label=launch;result.returns=1;stdout=;stderr=" "" ""
run_case "24-tabs-settings.pl" "space space j space j space" 0 0 "completed" "result.label=deploy;result.safe_mode=off;stdout=;stderr=" "" ""

if [ "$status" -eq 0 ]; then
    echo "All runnable examples verified successfully."
else
    echo "Runnable example verification failed."
fi

exit "$status"
