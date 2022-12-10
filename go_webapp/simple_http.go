package main

import (
	"database/sql"
	"fmt"
	"net/http"

	"os"

	_ "github.com/lib/pq"
)

const (
	host     = "db"
	port     = 5432
	user     = "test"
	password = "test"
	dbname   = "postgres"
)

func hello(w http.ResponseWriter, req *http.Request) {

	name, err := os.Hostname()
	if err != nil {
		panic(err)
	}

	//	fmt.Println("Run on ", name)

	psqlconn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", host, port, user, password, dbname)
	db, err := sql.Open("postgres", psqlconn)
	CheckError(err)

	rows, err := db.Query(`SELECT version();`)
	CheckError(err)

	defer db.Close()
	for rows.Next() {
		var db_version string

		err = rows.Scan(&db_version)
		CheckError(err)

		//fmt.Printf(w, "Database engine is ", version)
		fmt.Fprintf(w, name)
		fmt.Fprintf(w, "\n")
		fmt.Fprintf(w, db_version)
		db.Close()
	}
}

// func headers(w http.ResponseWriter, req *http.Request) {

// 	for name, headers := range req.Header {
// 		for _, h := range headers {
// 			fmt.Fprintf(w, "%v: %v\n", name, h)
// 		}
// 	}
// }

func CheckError(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {

	http.HandleFunc("/", hello)
	// http.HandleFunc("/headers", headers)

	http.ListenAndServe(":8090", nil)

	// CheckError(err)
}
