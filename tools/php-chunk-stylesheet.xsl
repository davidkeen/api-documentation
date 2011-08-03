<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version='1.0'>

  <!-- xsl:import href="http://docbook.sourceforge.net/release/xsl/current/html/chunk.xsl"/ -->
  <xsl:import href="xsl/html/chunk.xsl"/>

  <xsl:include href="base-html-stylesheet.xsl"/>

  <!-- PARAMETER REFERENCE:                                         -->
  <!-- http://docbook.sourceforge.net/release/xsl/current/doc/html/ -->

  <xsl:param name="chunker.output.encoding" select="'utf-8'"/>
  <xsl:param name="html.ext">.php</xsl:param>
  <xsl:param name="chunker.output.indent" select="'yes'"/>
  <xsl:param name="chunk.section.depth">0</xsl:param>

  <xsl:param name="toc.max.depth">2</xsl:param>

  <xsl:param name="use.id.as.filename">1</xsl:param>
  <xsl:param name="chunk.first.sections">1</xsl:param>
  <xsl:param name="chunk.quietly" select="1"></xsl:param>

  <xsl:param name="chapter.autolabel">0</xsl:param>
  <xsl:param name="appendix.autolabel">0</xsl:param>

  <xsl:param name="wordpress.dir">/var/www/www.amee.com</xsl:param>

  <!-- customised header output to add a style to chapter titles -->
  <xsl:template name="component.title">
    <xsl:param name="node" select="."/>
    <xsl:variable name="level">
      <xsl:choose>
        <xsl:when test="ancestor::section">
          <xsl:value-of select="count(ancestor::section)+1"/>
        </xsl:when>
        <xsl:when test="ancestor::sect5">6</xsl:when>
        <xsl:when test="ancestor::sect4">5</xsl:when>
        <xsl:when test="ancestor::sect3">4</xsl:when>
        <xsl:when test="ancestor::sect2">3</xsl:when>
        <xsl:when test="ancestor::sect1">2</xsl:when>
        <xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:element name="h{$level+1}">
      <xsl:attribute name="class">
        <xsl:choose>
          <xsl:when test="ancestor::chapter">title entry-title</xsl:when>
          <xsl:when test="ancestor::appendix">title entry-title</xsl:when>
          <xsl:when test="ancestor::bibliography">title entry-title</xsl:when>
          <xsl:otherwise>title</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:call-template name="anchor">
        <xsl:with-param name="node" select="$node"/>
        <xsl:with-param name="conditional" select="0"/>
      </xsl:call-template>
      <xsl:apply-templates select="$node" mode="object.title.markup">
        <xsl:with-param name="allow-anchors" select="1"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>
  
  <xsl:template name="chunk-element-content">
    <xsl:param name="prev"/>
    <xsl:param name="next"/>
    <xsl:param name="nav.context"/>
    <xsl:param name="content">
      <xsl:apply-imports/>
    </xsl:param>

    <xsl:variable name="doc" select="self::*"/>

    <xsl:call-template name="user.preroot"/>

    <xsl:processing-instruction name="php">
      require('<xsl:value-of select="$wordpress.dir"/>/wp-blog-header.php');
      class MyPost { var $post_title = "<xsl:apply-templates select="$doc" mode="object.title.markup.textonly"/>"; }
      $wp_query->is_home = false;
      $wp_query->is_page = true;
      $wp_query->is_404 = false;
      $wp_query->queried_object = new MyPost();
      get_header();
    <xsl:text>?</xsl:text></xsl:processing-instruction>

    <script type="text/javascript" src='script/jquery-1.5.min.js'></script>
    <script type="text/javascript" src='script/tabs.js'></script>
    <style type="text/css">
    .entry-meta {
            display: none!IMPORTANT;
            }
    #content {
            margin: 0px !important;
            }
    #container {
            width: 940px!important;
            clear: both!important;
            float: none!important;
    }
    .logo A{
            background-image: url(<xsl:processing-instruction name="php"> bloginfo('template_directory'); <xsl:text>?</xsl:text></xsl:processing-instruction>/images/AMEEdeveloper_logo.gif);
            background-repeat: no-repeat;
            background-position: left top;
            width:452px!important;
            }
    .logo A IMG{
            width:452px!important;
            height: 110px;
    }
    </style>
    <div id="containertwothirds">
      <div class="browserwide">
        <div id="content" class="contenttwothirds" role="main">
          
          <xsl:call-template name="body.attributes"/>

          <div id="content" class="narrowcolumn" role="main">
            <xsl:copy-of select="$content"/>
          </div>

          <xsl:call-template name="footer.navigation">
            <xsl:with-param name="prev" select="$prev"/>
            <xsl:with-param name="next" select="$next"/>
            <xsl:with-param name="nav.context" select="$nav.context"/>
          </xsl:call-template>

        </div>
      </div>
    </div>
    <div class="vertwidgets">
      <xsl:processing-instruction name="php">
        include (TEMPLATEPATH . '/sidebar-right.php');
      <xsl:text>?</xsl:text></xsl:processing-instruction>
    </div>

    <xsl:processing-instruction name="php">
      include (TEMPLATEPATH . '/footer_dev.php');
    <xsl:text>?</xsl:text></xsl:processing-instruction>

    <xsl:value-of select="$chunk.append"/>
  </xsl:template>
  
</xsl:stylesheet>