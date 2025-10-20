package util

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"time"
)

func SendHttpGETReq(reqUrl string, token string) (int, []byte, error) {
	req, err := http.NewRequest("GET", reqUrl, nil)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	if resp.StatusCode >= 400 {
		return resp.StatusCode, body, fmt.Errorf("HTTP error: status code %d, response: %s", resp.StatusCode, string(body))
	}

	return resp.StatusCode, body, nil
}

type Payload struct {
	Message []byte
}

func SendHttpPOSTReq(baseUrl string, query map[string]string, payload []byte, headers map[string]string, token string) (int, []byte, error) {

	var reqUrl string

	if query != nil {
		queryParams := url.Values{}
		for key, value := range query {
			queryParams.Add(key, value)
		}

		reqUrl = fmt.Sprintf("%s?%s", baseUrl, queryParams.Encode())

	} else {
		reqUrl = baseUrl
	}

	req, err := http.NewRequest("POST", reqUrl, bytes.NewReader(payload))
	if err != nil {
		return 0, nil, err
	}
	for key, value := range headers {
		req.Header.Set(key, value)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	if resp.StatusCode >= 400 {
		return resp.StatusCode, body, fmt.Errorf("HTTP error: status code %d, response: %s", resp.StatusCode, string(body))
	}

	return resp.StatusCode, body, nil
}

func SendHttpPOSTFileReq(baseUrl string, query map[string]string, payload *bytes.Buffer, headers map[string]string, token string) (int, []byte, error) {

	var reqUrl string

	if query != nil {
		queryParams := url.Values{}
		for key, value := range query {
			queryParams.Add(key, value)
		}

		reqUrl = fmt.Sprintf("%s?%s", baseUrl, queryParams.Encode())
	} else {
		reqUrl = baseUrl
	}

	req, err := http.NewRequest("POST", reqUrl, payload)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	for key, value := range headers {
		req.Header.Set(key, value)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	// log.Println("response Body:", string(body))

	if resp.StatusCode >= 400 {
		return resp.StatusCode, body, fmt.Errorf("HTTP error: status code %d, response: %s", resp.StatusCode, string(body))
	}

	return resp.StatusCode, body, nil
}

func SendHttpPUTReq(baseUrl string, query map[string]string, payload []byte, headers map[string]string, token string) (int, []byte, error) {

	var reqUrl string

	if query != nil {
		queryParams := url.Values{}
		for key, value := range query {
			queryParams.Add(key, value)
		}

		reqUrl = fmt.Sprintf("%s?%s", baseUrl, queryParams.Encode())
	} else {
		reqUrl = baseUrl
	}

	req, err := http.NewRequest("PUT", reqUrl, bytes.NewReader(payload))
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	for key, value := range headers {
		req.Header.Set(key, value)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	// log.Println("response Body:", string(body))

	if resp.StatusCode >= 400 {
		return resp.StatusCode, body, fmt.Errorf("HTTP error: status code %d, response: %s", resp.StatusCode, string(body))
	}

	return resp.StatusCode, body, nil
}

func SendHttpPATCHReq(baseUrl string, query map[string]string, payload []byte, headers map[string]string, token string) (int, []byte, error) {

	var reqUrl string

	if query != nil {
		queryParams := url.Values{}
		for key, value := range query {
			queryParams.Add(key, value)
		}

		reqUrl = fmt.Sprintf("%s?%s", baseUrl, queryParams.Encode())
	} else {
		reqUrl = baseUrl
	}

	req, err := http.NewRequest("PATCH", reqUrl, bytes.NewReader(payload))
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	for key, value := range headers {
		req.Header.Set(key, value)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Println(err)
		return 0, nil, err
	}

	// log.Println("response Body:", string(body))

	if resp.StatusCode >= 400 {
		return resp.StatusCode, body, fmt.Errorf("HTTP error: status code %d, response: %s", resp.StatusCode, string(body))
	}

	return resp.StatusCode, body, nil
}

func GetImageFileReqHeader() map[string]string {
	headers := map[string]string{
		"Content-Type": fmt.Sprintf("multipart/form-data; boundary=%s", GenerateRandomString(23)),
	}

	return headers
}

func GenerateRandomString(length int) string {
	rand.New(rand.NewSource(time.Now().UnixNano()))

	charset := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, length)
	for i := 0; i < length; i++ {
		result[i] = charset[rand.Intn(len(charset))]
	}

	return string(result)
}
