# GitHub Forms

A form engine built on GitHub

## Vision

## Installation

`script/bootstrap`

## Setup

1. Create an oauth application
2. `export GITHUB_CLIENT_ID=[GitHub Client ID]`
3. `export GITHUB_CLIENT_SECRET=[GitHub Client Secret]`
4. Create an oauth token for yourself or a user with write access to the file(s)
5. `export GITHUB_TOKEN=[GiHub Token]`

## Seting up on Heroku

Same as above, just use `heroku config:set` instead of `export`

## Running

1. `script/server`
2. Open [localhost:9292](http://localhost:9292) in your browser

## Usage

1. Create a CSV file on GitHub
2. Create a standard HTML form with fields matching each column
3. Replace `github.com` in the URL with your GitHub form server
