[![Build](https://github.com/wibosco/BackgroundTransferRevised-Example/actions/workflows/swift.yml/badge.svg)](https://github.com/wibosco/BackgroundTransferRevised-Example/actions/workflows/swift.yml)
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6-orange.svg?style=flat" alt="Swift 6" /></a>
[![License](http://img.shields.io/badge/License-MIT-green.svg?style=flat)](https://github.com/wibosco/BackgroundTransferRevised-Example/blob/main/LICENSE)

# BackgroundTransferRevised-Example
An example project showing how to use a background URLSession to keep downloads going even when the app is terminated as shown in this post - https://williamboles.com/keep-downloading-with-a-background-session/

This project uses [TheCatAPI](https://thecatapi.com/) to populate the app with downloaded images. `TheCatAPI` has an extensive library of freely available cat photos which it shares via a JSON-based API. While free to use, `TheCatAPI` does require you to [register](https://thecatapi.com/signup) to get full access to it's API (limited access is provided without an API key). Once registered you will be given an `x-api-key` token which you can paste as the `APIKey` value in `NetworkService` so that it is sent with each network request.

If you have any trouble getting the project to run, please create an issue.
