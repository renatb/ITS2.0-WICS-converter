# Test matching non-elements, which requires the usage of FutureNodes
use strict;
use warnings;
use t::TestXML2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {input => 'htmlize', log => [qw(lines chomp array)]};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note join "\n", @$log;
}

__DATA__
FutureNode management is used to remember matches and match locations,
even when elements are replaced or nodes are deleted

=== namespaced element match handled properly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//foo:para"
        domainPointer="//content" xmlns:foo="www.foo.com"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
  <content>foo</content>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule xmlns:foo="www.foo.com" selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">Some text</div>
        <div title="content" id="ITS_2">foo</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=<content>
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
processing <content>
setting @title of <content> to 'content'
renaming <content> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <div> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<div id="ITS_2">]

=== attribute match handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="@content"/>
    </its:rules>
  </head>
  <para content="foo">Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para[content='foo']" id="ITS_1">
          <span title="content" id="ITS_2" class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=@content[foo]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para[content='foo']'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type ATT
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

=== attribute match on namespaced element handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
      xmlns:its="http://www.w3.org/2005/11/its"
      xmlns:foo="foo.com">
      <its:translateRule selector="//foo:para/@content"
        translate="yes"/>
    </its:rules>
  </head>
  <foo:para content="foo" xmlns:foo="foo.com">Some text</foo:para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('ITS_1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para[content='foo']">
          <span title="content" id="ITS_1" class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:translateRule>; selector=@content[foo]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para[content='foo']'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Creating new <span> element to represent node of type ATT
Setting id of <span> to ITS_1
Creating new rule <its:translateRule> to match [selector=<span id="ITS_1">]

=== comment match handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="comment()"/>
    </its:rules>
  </head>
  <para>Some text<!--foo--></para>
  <para>Some text<!--foo-->more text</para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
      <its:domainRule selector="id('ITS_3')" domainPointer="id('ITS_4')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <!--foo-->
          <span title="#comment" id="ITS_2" class="_ITS_COM">
            foo
          </span>
        </div>
        <div title="para" id="ITS_3">
          Some text
          <!--foo-->
          <span title="#comment" id="ITS_4" class="_ITS_COM">
            foo
          </span>
          more text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=<!--foo-->
match: rule=<its:domainRule>; selector=<para>; domainPointer=<!--foo-->
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type COM
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Setting id of <div> to ITS_3
Creating new <span> element to represent node of type COM
Setting id of <span> to ITS_4
Creating new rule <its:domainRule> to match [selector=<div id="ITS_3">; domainPointer=<span id="ITS_4">]

=== processing instruction match handled correctly
PIs are illegal in HTML. They should all be removed; matched ones should have
a representing node.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <para>Some text<?foo_pi some content?></para>
  <?bar_pi junk?>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <span title="foo_pi" id="ITS_2" class="_ITS_PI">
            some content
          </span>
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=<?foo_pi?>
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type PI
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

=== processing instruction match handled correctly inside namespaced node
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com"><?foo_pi some content?></foo:para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          <span title="foo_pi" id="ITS_2" class="_ITS_PI">
            some content
          </span>
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=<?foo_pi?>
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type PI
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

=== text node match handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="text()"/>
    </its:rules>
  </head>
  <para>Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          <span class="_ITS_TXT" id="ITS_2" title="#text">
          Some text
          </span>
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=[text: Some text]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type TXT
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

=== namespace matches handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its" xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <span title="xmlns:foo" class="_ITS_NS" id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[namespace: xmlns:foo]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type NS
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

=== document matches handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its" xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="/"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml" id="ITS_2">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[DOCUMENT]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <div> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<div id="ITS_2">]
