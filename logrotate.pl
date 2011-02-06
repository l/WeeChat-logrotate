#
# logrotate.pl is written
# by "AYANOKOUZI, Ryuunosuke" <i38w7i3@yahoo.co.jp>
# under GNU General Public License v3.
#
# Name
#	logrotate.pl - yet another log rotation for weechatlog
#
# Discripton
#	logrotate is desined for rotation logfiles by using
#	pure weechat environment. it allows to automatic
#	rotate weechatlogs for any buffer with DIFFERRNT
#	configuration.
#	Prior to the consideration of using logrotate.pl,
#	check "WeeChat User’s Guid Section 4.7. Logger plugin"
#	first. WeeChat provide us official logrotate manner.
#
# Usage
# /set plugins.var.perl.logrotate.server.#channel.timer 600
#	Set log rotation timer 600 for the buffer named
#	server.#channel. weechatlog file will be rotated
#	for each 600 seconds.
#
# /set plugins.var.perl.logrotate.server.#channel.format /home/hoge/.weechat/logs/server.#channel/%Y-%m-%d-%H:%M:%S
#	Set logfile format for the buffer named server.#channel.
#	weechatlog file will be renamed according to the format.
#	Special calacters(%Y, %m, %d ...) defined in the perl
#	module Time::Piece are allowed to use, for the detail
#	information of them, check the URLs[1,2] below.
#
#	[1] http://www.unix.com/man-page/FreeBSD/3/strftime/
#	[2] http://search.cpan.org/~msergeant/Time-Piece/Piece.pm
#

use strict;
use warnings;
use Time::Piece;
use Data::Dumper;
use File::Basename;
use File::Path;

weechat::register("logrotate", "AYANOKOUZI, Ryuunosuke", "0.1.0", "GPL3", "logrotate", "", "");
weechat::hook_config("plugins.var.perl.logrotate.*", "config_cb", "");

my $conf = &config();

sub option_get
{
	my $prefix = shift;

	my $conf;
	my $il = weechat::infolist_get('option', '', "$prefix.*");
	while (weechat::infolist_next($il)) {
		my $full_name = weechat::infolist_string($il, 'full_name');
		if ($full_name =~ m/$prefix\.(.*)\.([^.]*)\Z/) {
			$conf->{$1}->{$2} = weechat::infolist_string($il, 'value');
		}
	}
	weechat::infolist_free($il);

	return $conf;
}

sub config
{
	my $conf = &option_get("plugins.var.perl.logrotate");
	while (my ($key, $val) = each %{$conf}) {
		$val->{hook} = weechat::hook_timer(1000 * $val->{timer}, $val->{timer}, 0, "my_signal_day_changed", $key);
	}

#	weechat::print("", Dumper $conf);
	return $conf;
}

sub config_cb
{
	my $data = shift;
	my $option = shift;
	my $value = shift;
	while (my ($key, $val) = each %{$conf}) {
		if ($val->{hook}) {
			weechat::unhook($val->{hook});
		}
	}
	$conf = &config();
	return weechat::WEECHAT_RC_OK;
}

sub my_signal_day_changed
{
#	weechat::print("", "");
#	weechat::print("", "test");
	my $data = shift;
	return weechat::WEECHAT_RC_OK if !defined $conf->{$data};

	my $il = weechat::infolist_get('buffer', '', "*$data*");
	while (weechat::infolist_next($il)) {
		my $name = weechat::infolist_string($il, 'name');
		next if $name ne $data;
#		weechat::print("", $name);
		my $pointer = weechat::infolist_pointer($il, 'pointer');
		my $il1 = weechat::infolist_get('logger_buffer', '', '');
		while (weechat::infolist_next($il1)) {
			my $buffer = weechat::infolist_pointer($il1, 'buffer');
			next if $buffer ne $pointer;
#			weechat::print("", $buffer);
			my $log_filename = weechat::infolist_string($il1, 'log_filename');
			next if $log_filename eq '';
#			weechat::print("", $log_filename);
			my $log_enabled = weechat::infolist_integer($il1, 'log_enabled');
			next if $log_enabled != 1;
#			weechat::print("", $log_enabled);
			my $log_level = weechat::infolist_integer($il1, 'log_level');
			next if $log_level == 0;
#			weechat::print("", $log_level);
			my $t = localtime;
			my $log_filename_new = $t->strftime($conf->{$name}->{format});
			eval { mkpath(dirname($log_filename_new)); };
			weechat::print("", "ERROR:mkpath, $@") && next if $@;
#			weechat::print("", $log_filename_new);
			rename $log_filename, $log_filename_new;
			weechat::print("", "$log_filename => $log_filename_new");
			weechat::command($buffer, "/mute logger disable");
			weechat::command($buffer, "/mute logger set $log_level");
		}
		weechat::infolist_free($il1);
	}
	weechat::infolist_free($il);

	return weechat::WEECHAT_RC_OK;
}
