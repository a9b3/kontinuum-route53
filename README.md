Create resource record set in route53.

## Requirements

- requires awscli `pip install awscli`

Set these env vars in the environment that is being used to run this script.

```
AWS_DEFAULT_REGION
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

- requires `jq`

*Note: Remember to set nameserver values for the domain*

### Usage

```sh
./script.sh --name <name> --root <root>
```

`--name`: must match s3 bucket

`--root`: root domain


TODO
only works for static sites via s3 buckets