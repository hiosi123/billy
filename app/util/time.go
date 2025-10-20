package util

import (
	"fmt"
	"strconv"
	"time"
)

const TimeFormat = "20060102150405"

func GetCurrentTime() time.Time {
	now := time.Now().UTC()
	koreaLocation := time.FixedZone("KST", 9*60*60)
	koreaNow := now.In(koreaLocation)

	return koreaNow
}

func GetRemainingTime(timeString, format string) (time.Duration, error) {
	targetTime, err := time.Parse(format, timeString)
	if err != nil {
		return 0, err
	}

	currentTime := GetCurrentTime().In(targetTime.Location())

	remainingTime := targetTime.Sub(currentTime)

	return remainingTime, nil
}

func ConvertUnixTimeStringToKST(unixTimeString string) (time.Time, error) {

	unixTime, err := strconv.ParseInt(unixTimeString, 10, 64)
	if err != nil {
		return time.Time{}, fmt.Errorf("error parsing Unix time: %w", err)
	}

	timeInUTC := time.Unix(unixTime, 0)

	loc, err := time.LoadLocation("Asia/Seoul")
	if err != nil {
		return time.Time{}, fmt.Errorf("error loading location: %w", err)
	}

	timeInKST := timeInUTC.In(loc)
	return timeInKST, nil
}

func ConvertLgFormat(dateStr string) (string, error) {
	inputLayout := "2006-01-02T15:04:05"

	outputLayout := TimeFormat

	t, err := time.Parse(inputLayout, dateStr)
	if err != nil {
		return "", err
	}

	compactFormat := t.Format(outputLayout)
	return compactFormat, nil
}
