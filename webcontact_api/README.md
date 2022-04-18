# Overview

Attaches a new '/contact' endpoint to an API gateway which is used to handle web based contact forms.

Message is sent to some recieving inbox via AWS SES with appropriate reply-to based on the email field of the form.

Google Recaptcha is used to prevent abuse - since this API endpoint is otherwise open
