package Toastr;
use Mojo::Base 'Mojo::IRC';

use IRC::Utils ();
use Mojo::Util 'decamelize';

has nick_ptn => sub { qr/\b([a-z_\-\[\]\\^{}|`]+)\b/i };

sub msg { shift->write( privmsg => shift, ":@_" ) }

sub parse_user { IRC::Utils::parse_user($_[1]->{prefix}) }

sub plugin {
  my ($self, $name, $args) = @_;
  my $module = "Toastr::Plugin::$name";
  return unless eval "require $module; 1";
  my $plugin = $module->new($args || {});
  $plugin->register($self);
  $self->attr(decamelize($name) => sub { $plugin });
  return $plugin;
}

sub start {
  my ($irc, $chans) = @_;
  $irc->register_default_event_handlers;

  $irc->on( irc_privmsg => \&_privmsg );
  $irc->on( irc_error => sub { warn $_[1] });

  $irc->connect(sub{
    my ($irc, $err) = @_;
    return warn $err if $err;
    $irc->write( join => $_ ) for @$chans;
  });

  $irc->ioloop->start;
}

sub _privmsg {
  my ($irc, $msg) = @_;
  my ($chan, $text) = @{ $msg->{params} };

  my $nick = $irc->nick;
  my $is_pm = 0;

  if ($chan eq $nick) {
    $chan = $irc->parse_user($msg);
    $is_pm = 1;
  }

  $irc->emit( toastr_privmsg => $chan, $text, $is_pm, $msg );

  if ($text =~ s/^\Q$nick\E\S*\s*// or $is_pm) {
    $irc->emit( toastr_direct_message => $chan, $text, $is_pm, $msg );
  }

  if ($text =~ /toast/) {
    $irc->emit( toastr_toast => $chan, $text, $msg );
  }
}

1;



