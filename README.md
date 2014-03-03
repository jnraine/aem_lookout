# AemLookout

Automatically deploys code changes while developing.

A short loop between when you make changes and when you see those changes is an important step to productivity!

## Install

```
gem install aem_lookout
```

or add the following to your Gemfile:

```
gem 'aem_lookout'
```

and run `bundle install` from your shell.

## Usage

1. Create a lookout.json file for your code base, similar to the (example config file)[https://github.com/jnraine/aem_lookout/blob/master/example_config.json].
2. Run `lookout` from the command line. May need to run `bundle exec lookout` if the executable is not found.
3. Edit files — .java, .css, .content.xml, whatever — and watch them deploy to your local instance.

## Contributing

1. Fork it ( http://github.com/<my-github-username>/aem_lookout/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
