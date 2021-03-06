#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBI;
use Encode;
use Config::INI::Reader;
#use Data::Dump qw/dump/;

use constant ERR_INCOMPATIBLE_GRAM => 1;
use constant ERR_UNKNOWN_GRAM => 2;
use constant ERR_DUPLICATE_FORMS => 3;
use constant ERR_MISSING_GRAM => 4;
use constant ERR_FORBIDDEN_GRAM => 5;

use constant RESTR_ALLOWED => 0;
use constant RESTR_OBLIGATORY => 1;
use constant RESTR_DISALLOWED => 2;

#reading config
my $conf = Config::INI::Reader->read_file($ARGV[0]);
$conf = $conf->{mysql};

#main
my %bad_pairs;
my %must;
my %may;
my %forbidden;

my %objtype = (
    0 => 'll',
    1 => 'lf',
    2 => 'fl',
    3 => 'ff'
);

my $dbh = DBI->connect('DBI:mysql:'.$conf->{'dbname'}.':'.$conf->{'host'}, $conf->{'user'}, $conf->{'passwd'}) or die $DBI::errstr;
$dbh->do("SET NAMES utf8");
my $clear = $dbh->prepare("DELETE FROM dict_errata WHERE rev_id IN (SELECT rev_id FROM dict_revisions WHERE lemma_id=?)");
my $update = $dbh->prepare("UPDATE dict_revisions SET dict_check='1' WHERE rev_id=? LIMIT 1");
my $scan = $dbh->prepare("SELECT rev_id, lemma_id, rev_text FROM dict_revisions WHERE dict_check=0 ORDER BY rev_id LIMIT 500");
my $scan0 = $dbh->prepare("SELECT gram_id, inner_id FROM gram WHERE parent_id=0");

my $all_gram = get_gram_info();
#print STDERR dump(%forbidden)."\n";
my @revisions = @{get_new_revisions()};
while(my $ref = shift @revisions) {
    $clear->execute($ref->{'lemma_id'});
    if ($ref->{'text'} ne '') {
        # an empty revision is created when a lemma is deleted
        check($ref, $all_gram);
    }
    $update->execute($ref->{'id'});
}

##### SUBROUTINES #####
sub get_new_revisions {
    $scan->execute();
    my $txt;
    my @revs;
    while(my $ref = $scan->fetchrow_hashref()) {
        $txt = decode('utf8', $ref->{'rev_text'});
        push @revs, {'id' => $ref->{'rev_id'}, 'lemma_id' => $ref->{'lemma_id'}, 'text' => $txt};
    }
    return \@revs;
}
sub get_gram_info {
    #bad pairs, all valid grammems
    $scan0->execute();
    my %h;
    my %all_grammems;
    while(my $ref = $scan0->fetchrow_hashref()) {
        %h = ();
        $h{$ref->{'inner_id'}} = 0;
        $all_grammems{$ref->{'inner_id'}} = 0;
        my $scan1 = $dbh->prepare("SELECT gram_id, inner_id FROM gram WHERE parent_id=".$ref->{'gram_id'});
        $scan1->execute();
        while(my $ref1 = $scan1->fetchrow_hashref()) {
            $h{$ref1->{'inner_id'}} = 0;
            $all_grammems{$ref1->{'inner_id'}} = 0;
            my $scan2 = $dbh->prepare("SELECT gram_id, inner_id FROM gram WHERE parent_id=".$ref1->{'gram_id'});
            $scan2->execute();
            while (my $ref2 = $scan2->fetchrow_hashref()) {
                $all_grammems{$ref2->{'inner_id'}} = 0;
                $h{$ref2->{'inner_id'}} = 0;
            }
        }
        if (scalar keys %h > 1) {
            #this is a cluster
            for my $k1(keys %h) {
                for my $k2(keys %h) {
                    next if $k1 eq $k2;
                    $bad_pairs{"$k1|$k2"} = $bad_pairs{"$k2|$k1"} = 0;
                }
            }
        }
    }
    #must
    my $scan1 = $dbh->prepare("SELECT g0.inner_id if_id, g1.inner_id then_id, g2.inner_id gram1, g3.inner_id gram2, r.restr_id, r.restr_type, r.obj_type
        FROM gram_restrictions r
        LEFT JOIN gram g0 ON (r.if_id = g0.gram_id)
        LEFT JOIN gram g1 ON (r.then_id = g1.gram_id)
        LEFT JOIN gram g2 ON (r.then_id = g2.parent_id)
        LEFT JOIN gram g3 ON (g2.gram_id = g3.parent_id)
        WHERE r.restr_type = ? OR r.restr_type = ?
        ORDER BY r.restr_type");
    $scan1->execute(RESTR_ALLOWED, RESTR_OBLIGATORY);
    my $last_id = 0;
    my @real = ();
    while (my $ref = $scan1->fetchrow_hashref()) {
        push @real, $ref->{'then_id'} if $ref->{'then_id'};
        push @real, $ref->{'gram1'} if $ref->{'gram1'};
        push @real, $ref->{'gram2'} if $ref->{'gram2'};
        my $if_id = $ref->{'if_id'} || '';
        my $otype = $ref->{'obj_type'};
        if ($ref->{'restr_type'} == RESTR_OBLIGATORY) {
            #grammem must be there in some cases
            if ($ref->{'restr_id'} != $last_id) {
                my %t;
                $t{$_} = 1 for (@real);
                push @{$must{$objtype{$otype}}{$if_id}}, \%t;
            }
            else {
                $must{$objtype{$otype}}{$if_id}[-1]{$_} = 1 for (@real);
            }
        }
        else {
            #grammem is allowed in some cases
            $may{swap2($objtype{$otype})}{$_}{$if_id} = 1 for (@real);
        }
        $last_id = $ref->{'restr_id'};
    }

    # deleting what is forbidden
    $scan1->execute(RESTR_DISALLOWED, RESTR_DISALLOWED);
    while(my $ref = $scan1->fetchrow_hashref()) {
        @real = ($ref->{'then_id'});
        push @real, $ref->{'gram1'} if $ref->{'gram1'};
        push @real, $ref->{'gram2'} if $ref->{'gram2'};
        delete $may{swap2($objtype{$ref->{'obj_type'}})}{$_}{$ref->{'if_id'}} for (@real);
        $forbidden{swap2($objtype{$ref->{'obj_type'}})}{$_}{$ref->{'if_id'}} = 1 for (@real);
    }

    return \%all_grammems;
}
sub check {
    my $ref = shift;
    my $allgram_ref = shift;

    my $newerr = $dbh->prepare("INSERT INTO dict_errata VALUES(NULL, ?, ?, ?, ?)");
    $ref->{'text'} =~ /<l t="(.+)">(.+)<\/l>/;
    my ($lt, $lg_str) = ($1, $2);
    my @lemma_gram = ();
    while($lg_str =~ /<g v="([^"]+)"\/>/g) {
        push @lemma_gram, $1;
    }

    if (my $err = is_incompatible(\@lemma_gram)) {
        $newerr->execute(time(), $ref->{'id'}, ERR_INCOMPATIBLE_GRAM, "<$lt> ($err)");
    }
    if (my $err = has_unknown_grammems(\@lemma_gram, $allgram_ref)) {
        $newerr->execute(time(), $ref->{'id'}, ERR_UNKNOWN_GRAM, "<$lt> ($err)");
    }
    if (my $err = misses_oblig_grammems_l(\@lemma_gram)) {
        $newerr->execute(time(), $ref->{'id'}, ERR_MISSING_GRAM, "<$lt> ($err)");
    }
    if (my $err = has_disallowed_grammems_l(\@lemma_gram)) {
        $newerr->execute(time(), $ref->{'id'}, ERR_FORBIDDEN_GRAM, "<$lt> ($err)");
    }

    my @form_gram = ();
    my $form_gram_str;
    my @all_gram = ();
    my %form_gram_hash = ();

    while($ref->{'text'} =~ /<f t="([^"]+)">(.*?)<\/f>/g) {
        my ($ft, $fg_str) = ($1, $2);
        @form_gram = ();
        while($fg_str =~ /<g v="([^"]+)"\/>/g) {
            push @form_gram, $1;
        }
        @all_gram = (@lemma_gram, @form_gram);
        if (my $err = is_incompatible(\@all_gram)) {
            $newerr->execute(time(), $ref->{'id'}, ERR_INCOMPATIBLE_GRAM, "<$ft> ($err)");
        }
        if (my $err = has_unknown_grammems(\@all_gram, $allgram_ref)) {
            $newerr->execute(time(), $ref->{'id'}, ERR_UNKNOWN_GRAM, "<$ft> ($err)");
        }
        if (my $err = misses_oblig_grammems_f(\@form_gram, \@lemma_gram)) {
            $newerr->execute(time(), $ref->{'id'}, ERR_MISSING_GRAM, "<$ft> ($err)");
        }
        if (my $err = has_disallowed_grammems_f(\@form_gram, \@lemma_gram)) {
            $newerr->execute(time(), $ref->{'id'}, ERR_FORBIDDEN_GRAM, "<$ft> ($err)");
        }
        $form_gram_str = join('|', sort @form_gram);
        if (my $f = $form_gram_hash{$form_gram_str}) {
            $newerr->execute(time(), $ref->{'id'}, ERR_DUPLICATE_FORMS, "<$ft>, <$f> ($form_gram_str)");
            return;
        } else {
            $form_gram_hash{$form_gram_str} = $ft;
        }
    }
}
sub is_incompatible {
    my @gram = @{shift()};
    for my $i(0..$#gram) {
        for my $j($i+1..$#gram) {
            exists $bad_pairs{$gram[$i].'|'.$gram[$j]} && return $gram[$i].'|'.$gram[$j];
        }
    }
    return 0;
}
sub has_unknown_grammems {
    my @gram = @{shift()};
    my $allgram_ref = shift;

    for my $g(@gram) {
        exists $allgram_ref->{$g} || return $g;
    }
    return 0;
}
sub misses_oblig_grammems_l {
    my @gram = @{shift()};

    if (exists $must{'ll'}{''}) {
        for my $cl(@{$must{'ll'}{''}}) {
            if (!has_any_grammem(\@gram, $cl)) {
                for my $clgr(keys %$cl) {
                    if (!has_any_grammem($forbidden{'ll'}{$clgr}, \@gram)) {
                        return join('|', keys %$cl);
                    }
                }
            }
        }
    }

    for my $gr(@gram) {
        if (exists $must{'ll'}{$gr}) {
            for my $cl(@{$must{'ll'}{$gr}}) {
                if (!has_any_grammem(\@gram, $cl)) {
                    for my $clgr(keys %$cl) {
                        if (!has_any_grammem($forbidden{'ll'}{$clgr}, \@gram)) {
                            return join('|', keys %$cl);
                        }
                    }
                }
            }
        }
    }
}
sub misses_oblig_grammems_f {
    my @form_gram = @{shift()};
    my @lemma_gram = @{shift()};

    if (exists $must{'lf'}{''}) {
        for my $cl(@{$must{'lf'}{''}}) {
            if (!has_any_grammem(\@form_gram, $cl)) {
                for my $clgr(keys %$cl) {
                    if (
                        !has_any_grammem($forbidden{'ff'}{$clgr}, \@form_gram) &&
                        !has_any_grammem($forbidden{'fl'}{$clgr}, \@lemma_gram)
                       ) {
                        return join('|', keys %$cl);
                    }
                }
            }
        }
    }

    for my $gr(@form_gram) {
        if (exists $must{'ff'}{$gr}) {
            for my $cl(@{$must{'ff'}{$gr}}) {
                if (!has_any_grammem(\@form_gram, $cl)) {
                    for my $clgr(keys %$cl) {
                        if (
                            !has_any_grammem($forbidden{'ff'}{$clgr}, \@form_gram) &&
                            !has_any_grammem($forbidden{'fl'}{$clgr}, \@lemma_gram)
                           ) {
                            return join('|', keys %$cl);
                        }
                    }
                }
            }
        }
    }

    for my $gr(@lemma_gram) {
        if (exists $must{'lf'}{$gr}) {
            for my $cl(@{$must{'lf'}{$gr}}) {
                if (!has_any_grammem(\@form_gram, $cl)) {
                    for my $clgr(keys %$cl) {
                        if (
                            !has_any_grammem($forbidden{'ff'}{$clgr}, \@form_gram) &&
                            !has_any_grammem($forbidden{'fl'}{$clgr}, \@lemma_gram)
                           ) {
                            return join('|', keys %$cl);
                        }
                    }
                }
            }
        }
    }

    return 0;
}
sub has_disallowed_grammems_l {
    my @gram = @{shift()};

    for my $gr(@gram) {
        if (exists $forbidden{'ll'}{$gr}) {
            if (has_any_grammem(\@gram, $forbidden{'ll'}{$gr})) {
                return $gr;
            }
        }
        next if exists $may{'ll'}{$gr}{''};
        if (exists $may{'ll'}{$gr}) {
            if (!has_any_grammem(\@gram, $may{'ll'}{$gr})) {
                return $gr;
            }
        }
    }

    return 0;
}
sub has_disallowed_grammems_f {
    my @form_gram = @{shift()};
    my @lemma_gram = @{shift()};

    for my $gr(@form_gram) {
        if (exists $forbidden{'fl'}{$gr}) {
            if (has_any_grammem(\@lemma_gram, $forbidden{'fl'}{$gr})) {
                return $gr;
            }
        }
        if (exists $forbidden{'ff'}{$gr}) {
            if (has_any_grammem(\@form_gram, $forbidden{'ff'}{$gr})) {
                return $gr;
            }
        }

        next if (exists $may{'fl'}{$gr}{''} || exists $may{'ff'}{$gr}{''});
        if (exists $may{'fl'}{$gr}) {
            if (!has_any_grammem(\@lemma_gram, $may{'fl'}{$gr})) {
                if (exists $may{'ff'}{$gr}) {
                    if (!has_any_grammem(\@form_gram, $may{'ff'}{$gr})) {
                        return $gr;
                    }
                }
                else {
                    return $gr;
                }
            }
        }
        elsif (exists $may{'ff'}{$gr}) {
            if (!has_any_grammem(\@form_gram, $may{'ff'}{$gr})) {
                return $gr;
            }
        }
        else {
            return $gr;
        }
    }

    return 0;
}
sub has_any_grammem {
    my $haystack_ref = shift;
    my $needle_ref = shift;
    my @haystack;
    my @needle;

    if (ref($haystack_ref) eq 'ARRAY') {
        @haystack = @$haystack_ref;
    }
    elsif (ref($haystack_ref) eq 'HASH') {
        @haystack = keys %$haystack_ref;
    }
    if (ref($needle_ref) eq 'ARRAY') {
        @needle = @$needle_ref;
    }
    elsif (ref($needle_ref) eq 'HASH') {
        @needle = keys %$needle_ref;
    }

    #printf STDERR "    searching for (%s) in (%s)\n", join(', ', @needle), join (', ', @haystack);

    for my $h(@haystack) {
        for my $n(@needle) {
            $h eq $n && return 1;
        }
    }
    return 0;
}
sub swap2 {
    my $s = shift;
    $s =~ s/(.)(.)/$2$1/;
    return $s;
}
