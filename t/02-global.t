# Test HTMLization of local ITS markup
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
=== single selector of element with id
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="id('i1')" translate="yes"/>
    </its:rules>
  </head>
  <para xml:id="i1">Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:translateRule selector="id('i1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para[xml:id='i1']" id="i1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:translateRule>; selector=<para xml:id="i1">
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para xml:id="i1">
renaming @xml:id of <para xml:id="i1"> to @id
setting @title of <para id="i1"> to 'para[xml:id='i1']'
renaming <para id="i1"> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Creating new rule <its:translateRule> to match [selector=<div id="i1">]

=== single selector of element without id
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="//para" translate="yes"/>
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
        <its:translateRule selector="id('ITS_1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:translateRule>; selector=<para>
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
Creating new rule <its:translateRule> to match [selector=<div id="ITS_1">]

=== multiple selectors
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="//content"/>
    </its:rules>
  </head>
  <para>Some text</para>
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
        <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
        <div title="content" id="ITS_2">foo</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=<content>
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
processing <content>
setting @title of <content> to 'content'
renaming <content> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <div> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<div id="ITS_2">]

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

=== DOM value match handled correctly
Below idValue is a literal string;
it should just be copied to the final rule.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:idValueRule selector="//para"
        idValue="'p1'"/>
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
        <its:idValueRule selector="id('ITS_1')" idValue="'p1'"></its:idValueRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:idValueRule>; selector=<para>; idValue=p1
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
Creating new rule <its:idValueRule> to match [selector=<div id="ITS_1">; idValue='p1']

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
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

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
          <!--foo-->
          <span title="#comment" id="ITS_2" class="_ITS_COM">
            foo
          </span>
        </div>
    </div>
  </body>
</html>
--- log
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
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new <span> element to represent node of type COM
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]

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
