package util

import (
	"strconv"

	"golang.org/x/text/encoding/korean"
	"golang.org/x/text/transform"
)

// euckr  (메시지 )
// cp949 (euckr 개선 버전)

func GetEucKrLength(str string) (int, error) {
	utf8Bytes := []byte(str)

	// Create transformer to convert UTF-8 to EUC-KR
	euckrEncoder := korean.EUCKR.NewEncoder()
	euckrBytes, _, err := transform.Bytes(euckrEncoder, utf8Bytes)
	if err != nil {
		return 0, err
	}

	return len(euckrBytes), nil
}

func GetStrlenInByteTNHMethod(str string) int {
	bytes := 0

	for _, ch := range str {
		if len(string(ch)) >= 3 {
			bytes += 2
		} else if ch == '\n' {
			bytes += 1
		} else {
			bytes += len(string(ch))
		}

	}

	return bytes
}

func StringToIntOrZero(value string) int {
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return 0 // Default to 0 if conversion fails
	}
	return intValue
}
