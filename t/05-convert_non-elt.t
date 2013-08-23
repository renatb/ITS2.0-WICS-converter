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
Elements are all renamed, so XPaths change accordingly.
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
<html>
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
All attributes, match or not, are turned into child elements (just testing
match here). This also triggers anti-inheritance rules.
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          <span
              title="content"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_ATT">
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
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new <span> element to represent node of type ATT (content)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance

=== multiple matches on one attribute handled correctly
Multiple matches of one attribute should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="@content"/>
      <its:domainRule selector="//para"
        domainPointer="@content"/>
    </its:rules>
  </head>
  <para content="foo">Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          <span
              title="content"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=@content[foo]
match: rule=<its:domainRule>; selector=<para>; domainPointer=@content[foo]
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
Creating new <span> element to represent node of type ATT (content)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance

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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('ITS_1')" translate="no"></its:translateRule>
      <its:translateRule selector="id('ITS_1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para">
          <span
              title="content"
              id="ITS_1"
              its-within-text="no"
              class="_ITS_ATT">
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
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new <span> element to represent node of type ATT (content)
Creating new its:rules element to contain all rules
Setting id of <span> to ITS_1
Creating new rule <its:translateRule> to match [selector=<span id="ITS_1">]
Creating new rule <its:translateRule> to prevent false inheritance

=== comment match handled correctly
Nothing is done to comments. Just need a new XPath for the new document.
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="/html/body/div/div[2]/comment()"></its:domainRule>
      <its:domainRule selector="id('ITS_2')" domainPointer="/html/body/div/div[3]/comment()"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <!--foo-->
        </div>
        <div title="para" id="ITS_2">
          Some text
          <!--foo-->
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
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<!--foo-->]
Setting id of <div> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_2">; domainPointer=<!--foo-->]

=== PI match handled correctly
PIs are illegal in HTML. They should all be removed. Matched PIs are turned
into child elements, which also triggers anti-inheritance rules.
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
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
Creating new <span> element to represent node of type PI (foo_pi)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== multiple matches on one PI handled correctly
Multiple matches for one node should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <para>Some text<?foo_pi some content?></para>
  <?bar_pi junk?>
</xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
            some content
          </span>
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=<?foo_pi?>
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
Creating new <span> element to represent node of type PI (foo_pi)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== PI match handled correctly inside namespaced node
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
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
Creating new <span> element to represent node of type PI (foo_pi)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== text node match handled correctly
Nothing is done to these. Just need a new XPath.
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="/html/body/div/div[2]/text()"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
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
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=[text: Some text]]

=== namespace matches handled correctly
Namespace matches are turned into elements in the document root, which also
triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
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
Creating new <span> element to represent node of type NS (xmlns:foo)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== multiple matches on same namespace handled correctly
Multiple matches of same namespace should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[namespace: xmlns:foo]
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
Creating new <span> element to represent node of type NS (xmlns:foo)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== namespace match inside namespaced node is handled correctly
Not really sure that namespaced parent makes a difference, but just to be safe,
test it.
--- input
<?xml version="1.0"?>
<bar:xml xmlns:bar="www.bar.com">
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its" xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*[name()='foo']"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</bar:xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:dirRule selector="id('ITS_2')" dir="ltr"></its:dirRule>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"></its:localeFilterRule>
      <its:translateRule selector="id('ITS_2')" translate="no"></its:translateRule>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="bar:xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[namespace: xmlns:foo]
converting document elements into HTML
processing <bar:xml>
setting @title of <bar:xml> to 'bar:xml'
stripping namespaces from <bar:xml>
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
Creating new <span> element to represent node of type NS (xmlns:foo)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance

=== document matches handled correctly
Document match stays the same ("/").
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
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="/"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
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
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=[DOCUMENT]]

=== namespaced document matches handled correctly
Namespacing probably doesn't make a difference here; just covering the bases.
--- input
<?xml version="1.0"?>
<foo:xml xmlns:foo="www.foo.com">
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="/"/>
    </its:rules>
  </head>
  <para xmlns:foo="www.foo.com">Some text</para>
</foo:xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:domainRule selector="id('ITS_1')" domainPointer="/"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="foo:xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
        </div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=[DOCUMENT]
converting document elements into HTML
processing <foo:xml>
setting @title of <foo:xml> to 'foo:xml'
stripping namespaces from <foo:xml>
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
stripping namespaces from <para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=[DOCUMENT]]

=== non-ITS, non-xmlns attributes are saved
All document attributes are saved as elements, which also
triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <para foo="bar" xmlns="blah">Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('ITS_1')" translate="no"></its:translateRule>
      </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="para">
          <span
            id="ITS_1"
            class="_ITS_ATT"
            its-within-text="no"
            title="foo">bar</span>
          Some text
        </div>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <para>
setting @title of <para> to 'para'
stripping namespaces from <para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new <span> element to represent node of type ATT (foo)
Creating new its:rules element to contain all rules
Setting id of <span> to ITS_1
Creating new rule <its:translateRule> to prevent false inheritance
