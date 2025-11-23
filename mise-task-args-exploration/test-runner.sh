#!/usr/bin/env bash
# Test Runner for Mise Task Arguments Exploration
# This script helps test all the examples systematically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Check if mise is installed
if ! command -v mise &> /dev/null; then
    echo -e "${RED}Error: mise is not installed${NC}"
    echo "Install mise: curl https://mise.run | sh"
    exit 1
fi

echo -e "${BLUE}=== Mise Task Arguments Test Runner ===${NC}\n"
echo "Mise version: $(mise --version)"
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"  # "pass", "fail", or "skip"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${YELLOW}Testing:${NC} $test_name"
    echo -e "${BLUE}Command:${NC} $command"

    if [ "$expected_result" = "skip" ]; then
        echo -e "${YELLOW}Status:${NC} SKIPPED (requires specific setup)\n"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi

    if eval "$command" > /dev/null 2>&1; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}Status:${NC} PASSED\n"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}Status:${NC} FAILED (expected to fail but passed)\n"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [ "$expected_result" = "fail" ]; then
            echo -e "${GREEN}Status:${NC} PASSED (correctly failed)\n"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}Status:${NC} FAILED (unexpected failure)\n"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Change to the exploration directory
cd "$(dirname "$0")"

echo -e "${BLUE}=== Basic Functionality Tests ===${NC}\n"

run_test "List all tasks" \
    "mise tasks" \
    "pass"

run_test "Basic test task help" \
    "mise run test:basic --help" \
    "pass"

run_test "Debug test help" \
    "mise run test:debug --help" \
    "pass"

run_test "Coverage test help" \
    "mise run test:coverage --help" \
    "pass"

run_test "Full test suite help" \
    "mise run test:full --help" \
    "pass"

echo -e "${BLUE}=== Flag Validation Tests ===${NC}\n"

run_test "Choice validation - valid choice" \
    "mise run test:env --env local --help" \
    "pass"

run_test "Choice validation - invalid choice" \
    "mise run test:env --env invalid" \
    "fail"

run_test "Required flag - missing" \
    "mise run edge:required-missing" \
    "fail"

run_test "Required flag - provided" \
    "mise run edge:required-missing --config test.yaml" \
    "skip"

echo -e "${BLUE}=== Variadic Arguments Tests ===${NC}\n"

run_test "Variadic - empty (optional)" \
    "mise run edge:variadic-empty" \
    "skip"

run_test "Min/Max validation - too few" \
    "mise run edge:minmax file1.py" \
    "fail"

run_test "Min/Max validation - just right" \
    "mise run edge:minmax -- file1.py file2.py" \
    "skip"

run_test "Min/Max validation - too many" \
    "mise run edge:minmax -- f1 f2 f3 f4 f5 f6" \
    "fail"

echo -e "${BLUE}=== Boolean and Negation Tests ===${NC}\n"

run_test "Boolean types test" \
    "mise run edge:boolean-types" \
    "skip"

run_test "Negate flag - default (true)" \
    "mise run edge:negate-default" \
    "skip"

run_test "Negate flag - explicit --no-cache" \
    "mise run edge:negate-default --no-cache" \
    "skip"

echo -e "${BLUE}=== Counting Flags Tests ===${NC}\n"

run_test "Count flag - zero" \
    "mise run edge:count-edge" \
    "skip"

run_test "Count flag - three" \
    "mise run edge:count-edge -vvv" \
    "skip"

echo -e "${BLUE}=== Environment Variable Tests ===${NC}\n"

run_test "Environment variable integration" \
    "mise run edge:env-expansion" \
    "skip"

run_test "Empty vs undefined" \
    "mise run edge:empty-vs-undefined" \
    "skip"

echo -e "${BLUE}=== Multi-Run Commands Tests ===${NC}\n"

run_test "Multi-run variable scope" \
    "mise run edge:multi-run-scope --value test" \
    "skip"

echo -e "${BLUE}=== Edge Cases Tests ===${NC}\n"

run_test "Special characters in paths" \
    "mise run edge:special-chars -- 'test file.py'" \
    "skip"

run_test "Unicode characters" \
    "mise run edge:unicode --name José" \
    "skip"

run_test "Whitespace in defaults" \
    "mise run edge:whitespace-default" \
    "skip"

run_test "Double dash separation" \
    "mise run edge:double-dash --flag value -- arg1 arg2" \
    "skip"

run_test "Conflicting flags" \
    "mise run edge:conflicts --verbose --quiet" \
    "skip"

run_test "Required unless/if" \
    "mise run edge:required-combo" \
    "fail"

run_test "Required unless/if - stdin" \
    "mise run edge:required-combo --stdin" \
    "skip"

run_test "Required unless/if - file" \
    "mise run edge:required-combo --file test.yaml" \
    "skip"

echo -e "${BLUE}=== Test Summary ===${NC}\n"
echo "Total Tests:   $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC}        $PASSED_TESTS"
echo -e "${RED}Failed:${NC}        $FAILED_TESTS"
echo -e "${YELLOW}Skipped:${NC}       $SKIPPED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi
