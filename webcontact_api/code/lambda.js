'use strict';

const aws   = require('aws-sdk');
const https = require('https');
const ses   = new aws.SES({region: 'us-east-1'});

const DOMAIN           = process.env['DOMAIN'];
const RECEIVER         = process.env['RECEIVER'];
const SENDER           = process.env['SENDER'] || `webcontact@${DOMAIN}`;
const RECAPTCHA_SECRET = process.env['RECAPTCHA_SECRET'];

function validateRequestBody(req_body){
  let errors = [];

  if(req_body.name === undefined || req_body.name === ''){
    errors.push({ field: 'name', message: 'Name cannot be empty' });
  }
  if(req_body.email === undefined || req_body.email === ''){
    errors.push({ field: 'email', message: 'Email cannot be empty' });
  } else if (!req_body.email.match(/^[^@\s]+@[^@\.\s]+\.[^@\s]+$/)){
    errors.push({ field: 'email', message: 'Email address is invalid' });
  }
  if(req_body.subject === undefined || req_body.subject === ''){
    errors.push({ field: 'subject', message: 'Subject cannot be empty' });
  }
  if(req_body.message === undefined || req_body.message === ''){
    errors.push({ field: 'message', message: 'Message cannot be empty' });
  }
	if(req_body['g-recaptcha-response'] === undefined || req_body['g-recaptcha-response'] === '') {
		errors.push({ field: 'recaptcha', message: 'You must complete the recaptcha challenge' });
	}

  return errors;
}

function sendEmail(req_body){
  let params = {
    Destination: {
      ToAddresses: [ RECEIVER ],
    },
    Message: {
      Body: {
        Text: { Data: req_body.message },
      },
      Subject: { Data: req_body.subject },
    },

    // Email to which reject messages will be sent
    ReturnPath: `bounces@${DOMAIN}`,

    // Who is sending the email? We can't send from the user's email address, so
    // instead send from an address we own, and then use ReplyTo to ensure
    // that human replies go to the correct place
    Source: SENDER,
    ReplyToAddresses: [ req_body.email ],
  };

  console.log("Sending email " + JSON.stringify(params));

  return new Promise((resolve, reject) => {
    ses.sendEmail(params, (err, data) => {
      if(err){
        reject(err);
      } else {
        resolve(err);
      }
    });
  });
}

function validateRecaptcha(event, value) {
	const options = {
    hostname: 'www.google.com',
    path: '/recaptcha/api/siteverify',
    method: 'POST',
    port: 443,
    headers: {
			'Accept'       : 'application/json',
      'Content-Type' : 'application/x-www-form-urlencoded'
    },
  };

	const body = [
    `remoteip=${event.requestContext.identity.sourceIp}`,
    `secret=${RECAPTCHA_SECRET}`,
    `response=${value}`,
  ].join('&');

  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      let rawData = '';

      res.on('data', chunk => {
        rawData += chunk;
      });

      res.on('end', () => {
        try {
          resolve(JSON.parse(rawData));
        } catch (err) {
          reject(new Error(err));
        }
      });
    });

    req.on('error', err => {
      reject(new Error(err));
    });

    // Write the body to the Request object
    req.write(body);
    req.end();
  });
}

exports.handler = async event => {
  let req_body = JSON.parse(event.body);

  ///////////////////////////////////////////
  // Generate correct response headers, including allowing CORS request from frontend
  let headers = {
    'Content-Type': 'application/json',
  };
  if(event?.headers.origin && event.headers.origin.match(new RegExp(`localhost|${DOMAIN}`))){
    console.log("Permitting CORS request for " + event.headers.origin);
    headers['Access-Control-Allow-Origin'] = event.headers.origin;
    headers['Vary'] = 'Origin'; // notify caches that headers can vary based on origin of request
  } else {
    console.log("Not attaching CORS authorization headers for origin: " + event.headers.origin);
  }

  ///////////////////////////////////////////
  // Check body has correct parameters
  let errors = validateRequestBody(req_body);
  if(errors.length > 0){
    return {
      headers,
			statusCode : 422,
      body       : JSON.stringify({
        success : false,
        errors  : errors,
      }),
    };
  }

  ///////////////////////////////////////////
  // Validate recaptcha
	try {
		let out = await validateRecaptcha(event, req_body['g-recaptcha-response']);
		if(!out.success) {
			console.warn("reCAPTCHA validation failed");
			console.dir(out);
			throw new Error('Recaptha was invalid');
		}
		console.log('Successfully validated recaptcha');
	} catch (e) {
		console.error(e);
		return {
			headers,
			statusCode : 422,
			body       : JSON.stringify({
				success: false,
				errors: [{ field: 'recaptha', message: 'reCAPTCHA could not be validated, please try again' }],
			}),
		};
	}

  ///////////////////////////////////////////
  // Send the mail
  try {
    await sendEmail(req_body);
    return {
      headers, statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (e) {
    console.warn("Failed to send email");
    console.dir(e);
    return {
      headers, statusCode: 500,
      body: JSON.stringify({
        success: false,
        errors: [{ message: `An unknown error prevented the sending of this message - please try again later, or send an email to hello@${DOMAIN}` }],
      }),
    };
  };

};
