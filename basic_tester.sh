#!/usr/bin/env bash

# Configuration
BINARY_NAME="a.out"
REFERENCE_EXT=".txt"
CXX="clang++"
CXXFLAGS="-std=c++20 -Wall -Wextra -Werror"
TIMEOUT_DURATION=2

XML_OUTPUT_DIR="test-results"
mkdir -p "$XML_OUTPUT_DIR"

escape_xml() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g'
}

generate_junit_xml() {
    local test_name="$1"
    local passed="$2"
    local output="$3"
    local error_msg="$4"
    local xml_file="$XML_OUTPUT_DIR/TEST-${test_name}.xml"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    local escaped_output=$(escape_xml "$output")
    local escaped_error=$(escape_xml "$error_msg")
    
    cat > "$xml_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="${test_name}" tests="1" failures="$((passed ? 0 : 1))" errors="0" timestamp="${timestamp}" time="1.0">
    <testcase name="output_test" classname="${test_name}" time="1.0">
EOF
    
    if [ "$passed" -eq 0 ]; then
        cat >> "$xml_file" << EOF
      <failure message="Test failed" type="FAILURE">
        <![CDATA[Expected output differs from actual output
        ${escaped_error}
        Student output:
        ${escaped_output}]]>
      </failure>
EOF
    fi
    
    cat >> "$xml_file" << EOF
      <system-out>
        <![CDATA[${escaped_output}]]>
      </system-out>
    </testcase>
  </testsuite>
</testsuites>
EOF
}

test_exercise() {
    local ex_num="$1"
    local ex_dir="ex$(printf "%02d" $ex_num)"
    local test_name="ex${ex_num}"
    
    echo -e "\n\033[1;34m[ Exercise ${ex_num} ]\033[0m"
    
    if [ ! -d "$ex_dir" ]; then
        echo "  Directory not found"
        return
    fi
    
    local main_file="${ex_dir}/ex${ex_num}.cpp"
    local ref_file="${ex_dir}/ex${ex_num}${REFERENCE_EXT}"
    
    if [ ! -f "$main_file" ]; then
        echo "  No main file found"
        generate_junit_xml "$test_name" 0 "" "Main file ex${ex_num}.cpp not found"
        return
    fi
    
    if [ ! -f "$ref_file" ]; then
        echo "  No reference file found"
        generate_junit_xml "$test_name" 0 "" "Reference file ex${ex_num}.txt not found"
        return
    fi
    
    echo -n "  Compiling... "
    
    local cpp_files=$(find "$ex_dir" -name "*.cpp" -type f | tr '\n' ' ')
    $CXX $CXXFLAGS $cpp_files -o "${ex_dir}/${BINARY_NAME}" 2> "${ex_dir}/compile_error.log"
    
    if [ $? -ne 0 ]; then
        echo -e "\033[0;31mFAIL\033[0m"
        local compile_error=$(cat "${ex_dir}/compile_error.log")
        generate_junit_xml "$test_name" 0 "$compile_error" "Compilation failed"
        return
    fi
    echo -e "\033[0;32mOK\033[0m"
    
    echo -n "  Running... "
    
    local student_output=""
    local timeout_output=$(timeout $TIMEOUT_DURATION "./${ex_dir}/${BINARY_NAME}" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        echo -e "\033[0;31mTIMEOUT\033[0m"
        student_output="Timeout after ${TIMEOUT_DURATION}s"
        generate_junit_xml "$test_name" 0 "$student_output" "Execution timeout"
    elif [ $exit_code -ne 0 ]; then
        echo -e "\033[0;31mRUNTIME ERROR\033[0m"
        student_output="$timeout_output"
        generate_junit_xml "$test_name" 0 "$student_output" "Runtime error (exit code: $exit_code)"
    else
        student_output="$timeout_output"
        
        if diff -w -B -q <(echo "$student_output") "$ref_file" > /dev/null 2>&1; then
            echo -e "\033[0;32mPASS\033[0m"
            generate_junit_xml "$test_name" 1 "$student_output" ""
        else
            echo -e "\033[0;31mFAIL\033[0m"
            local expected_output=$(cat "$ref_file")
            local diff_output=$(diff -u <(echo "$expected_output") <(echo "$student_output") 2>&1 || true)
            generate_junit_xml "$test_name" 0 "$student_output" "$diff_output"
        fi
    fi
    
    rm -f "${ex_dir}/${BINARY_NAME}" "${ex_dir}/compile_error.log"
}

echo "======================================="
echo "  EPITECH TESTER - JUNIT XML OUTPUT   "
echo "======================================="

find . -name "$BINARY_NAME" -type f -delete 2>/dev/null
find . -name "*.o" -type f -delete 2>/dev/null
rm -rf "$XML_OUTPUT_DIR"
mkdir -p "$XML_OUTPUT_DIR"

for i in {0..5}; do
    test_exercise $i
done

echo -e "\n======================================="
echo "  TESTS COMPLETED"
echo "  XML files generated in: $XML_OUTPUT_DIR/"
echo "======================================="

echo -e "\nGenerated XML files:"
find "$XML_OUTPUT_DIR" -name "*.xml" -type f | while read xml; do
    echo "  - $xml"
done
