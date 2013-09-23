# GitHub Forms

A RESTful API for submitting standard HTML form data to a GitHub-hosted CSV.

## Vision

GitHub supports CSVs. That's awesome. But what if you want to store user input, such as RSVPs or other form submissions? Well, now you can. Just replace `github.com` in the URL with the URL to your GitHub Forms server, and your standard HTML Form can now commit to GitHub.

Upon submission, the user is asked to Oauth, if they've not already, their identity is verified and the information is appended to the CSV.

## Demo

* [The form](http://github-forms.herokuapp.com/)
* [The fata](https://github.com/benbalter/github-forms/blob/example/example.csv)
* [The submission history](https://github.com/benbalter/github-forms/commits/example/example.csv)

## Roadmap / Wish list

* HTML form builder
* Git storage of form definitions
* Pull requests (sans conflicts)
* Gemification

## Installation

`script/bootstrap`

## Setup

1. Create an oauth application
2. `export GITHUB_CLIENT_ID=[GitHub Client ID]`
3. `export GITHUB_CLIENT_SECRET=[GitHub Client Secret]`
4. Create an oauth token for yourself or a user with write access to the file(s)
5. `export GITHUB_TOKEN=[GiHub Token]`

## Seting up on Heroku

Same as above, just use `heroku config:set` instead of `export`.

You'll also want to run `heroku addons:add redistogo:nano` to set up a free redis instance.

## Running

1. `script/server`
2. Open [localhost:9292](http://localhost:9292) in your browser

## Usage

1. Create a CSV file on GitHub
2. Create a standard HTML form with fields matching each column
3. Replace `github.com` in the URL with your GitHub form server
