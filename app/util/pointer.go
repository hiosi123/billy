package util

import "time"

func SafeStr(s *string) string {
	if s != nil {
		return *s
	}
	return ""
}

func SafeInt(i *int) int {
	if i != nil {
		return *i
	}
	return 0
}

func SafeInt8(i *int8) int8 {
	if i != nil {
		return *i
	}
	return 0
}

func SafeInt64(i *int64) int64 {
	if i != nil {
		return *i
	}
	return 0
}

func SafeFloat64(i *float64) float64 {
	if i != nil {
		return *i
	}
	return 0
}

// StrPtr takes a string and returns a pointer to it, or nil if the string is empty.
func StrPtr(s string) *string {
	if s != "" {
		return &s
	}
	return nil
}

// SafeIntPtr takes an int and returns a pointer to it, or nil if the int is 0.
func IntPtr(i int) *int {
	if i != 0 {
		return &i
	}
	return nil
}

// Int64Ptr takes an int64 and returns a pointer to it, or nil if the int64 is 0.
func Int64Ptr(i int64) *int64 {
	if i != 0 {
		return &i
	}
	return nil
}

// Float64Ptr takes a float64 and returns a pointer to it, or nil if the float64 is 0.
func Float64Ptr(i float64) *float64 {
	if i != 0 {
		return &i
	}
	return nil
}

// TimePtr takes a time.Time and returns a pointer to it, or nil if the time is the zero value.
func TimePtr(t time.Time) *time.Time {
	if !t.IsZero() {
		return &t
	}
	return nil
}

func BoolPtr(b bool) *bool {
	return &b
}
