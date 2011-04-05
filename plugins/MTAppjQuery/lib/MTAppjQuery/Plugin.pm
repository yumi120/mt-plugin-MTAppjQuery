package MTAppjQuery::Plugin;
use strict;
use utf8;
use MT::Website;
use MT::Blog;
use MT::Util;
use MT::Theme;
use MTAppjQuery::Tmplset;


###
##
#
use MT::Log;
use Data::Dumper;
sub doLog {
    my ($msg) = @_;     return unless defined($msg);
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}
#
##
###

sub cb_tmpl_source_header {
	my ($cb, $app, $tmpl_ref) = @_;
# my $q = $app->param;
# doLog('$app->param! : '.Dumper($q));
    my $p = MT->component('mt_app_jquery');
    
    ### 各種IDを取得する
    my $_type       = $app->param('_type') || 'type';
    my $id          = $app->param('id') || 0;
    my $blog_id     = $app->param('blog_id') || 0;
    # オブジェクトのタイプを判別して各オブジェクトのIDを取得する
    my $entry_id    = $_type eq 'entry' ? $id : 0;
    my $page_id     = $_type eq 'page' ? $id : 0;
    my $category_id = $_type eq 'category' ? $id : 0;
    my $template_id = $_type eq 'template' ? $id : 0;
    my $folder_id   = $_type eq 'folder' ? $id : 0;
    my $asset_id    = $_type eq 'asset' ? $id : 0;
    my $comment_id  = $_type eq 'comment' ? $id : 0;
    my $ping_id     = $_type eq 'ping' ? $id : 0;
    my $user_id     = $_type eq 'author' ? $id : 0; # ログイン中のユーザーは author_id だよ
    my $field_id    = $_type eq 'field' ? $id : 0;

    ### 各種パスを取得する（スラッシュで終わる）
    my $static_path        = $app->static_path;
    my $static_plugin_path = $static_path . $p->envelope . '/';

	### プラグインの設定の値を取得する
	my $op_no_usercss     = $p->get_setting('no_usercss', 0)     || 0;
	my $op_no_userjs      = $p->get_setting('no_userjs', 0)      || 0;
	my $op_no_slidemenu   = $p->get_setting('no_slidemenu', 0)   || 0;
	my $op_superslidemenu = $p->get_setting('superslidemenu', 0) || 0;
	my $op_sys_jsfreearea = $p->get_setting('sys_jqplugin', 0)   || '';
	
	my $op_active         = $p->get_setting('active', $blog_id)    || 1;
	my $op_usercss        = $p->get_setting('usercss', $blog_id)   || 1;
	my $op_userjs         = $p->get_setting('userjs', $blog_id)    || 1;
	my $op_slidemenu      = $p->get_setting('slidemenu', $blog_id) || 1;
	my $op_jsfreearea     = $p->get_setting('jqplugin', $blog_id)  || '';

	return if ($blog_id > 0 && $op_active == 0);

	my ($user_css, $set_blog_id, $js_freearea, $user_js, $super_slide_menu_js);
        
    ### ローディング画像、再構築アイコン、ツールチップ用ボックスをページに追加する
    my $target = '<div id="container"';
    my $preset = <<__MTML__;
    <mt:setvarblock name="html_body_footer" append="1">
    <img id="mtapp-loading"
         src="${static_path}images/indicator.gif"
         alt="<__trans_section component="mt_app_jquery"><__trans phrase="Page Loading"></__trans_section>" />
    <img id="mtapp-rebuild-icon"
         class="mtapp-hidden"
         src="${static_plugin_path}images/rebuild-mini.png"
         alt="<__trans_section component="mt_app_jquery"><__trans phrase="Rebuild"></__trans_section>" />
    <div id="mtapp-tooltip" style="display: none;"></div>
    </mt:setvarblock>
    ${target}
__MTML__
    $$tmpl_ref =~ s/$target/$preset/g;

    ### スライドメニューをセットする
    if ($op_no_slidemenu != 1 && $op_superslidemenu == 0 && ($op_slidemenu == 1 or $blog_id == 0)) {
        my $s_menu_org = MTAppjQuery::Tmplset::s_menu_org;
        my $w_menu_org = MTAppjQuery::Tmplset::w_menu_org;
        my $b_menu_org = MTAppjQuery::Tmplset::b_menu_org;
        my $s_menu     = MTAppjQuery::Tmplset::s_menu;
        my $w_menu     = MTAppjQuery::Tmplset::w_menu;
        my $b_menu     = MTAppjQuery::Tmplset::b_menu;
        $$tmpl_ref =~ s!$s_menu_org!$s_menu!g;
        $$tmpl_ref =~ s!$w_menu_org!$w_menu!g;
        $$tmpl_ref =~ s!$b_menu_org!$b_menu!g;
    }
    
    ### スーパースライドメニューをセットする
    if ($op_superslidemenu == 1) {
        ### websiteとblogのjsonを生成
        my (@websites, @websites_json, @blogs, @blogs_json, $websites_json, $blogs_json);
        push @websites, MT::Website->load(undef, {unique => 1});
        push @blogs, MT::Blog->load(undef, {unique => 1});
    
        foreach my $website (@websites) {
            my @theme_thumb = $website->theme 
                ? $website->theme->thumbnail( size => 'small' )
                : MT::Theme->default_theme_thumbnail( size => 'small' ); 
            my $websites_hash = $website->column_values;
            my %website_data = %$websites_hash;
            $website_data{'theme_thumb'} = $theme_thumb[0];
            push @websites_json, MT::Util::to_json(\%website_data);
        }
        $websites_json = join ",", @websites_json;
    
        foreach my $blog (@blogs) {
            my @theme_thumb = $blog->theme 
                ? $blog->theme->thumbnail( size => 'small' )
                : MT::Theme->default_theme_thumbnail( size => 'small' ); 
            my $blogs_hash = $blog->column_values;
            my %blog_data = %$blogs_hash;
            $blog_data{'theme_thumb'} = $theme_thumb[0];
            push @blogs_json, MT::Util::to_json(\%blog_data);
        }
        $blogs_json = join ",", @blogs_json;
    
# doLog("blogs_json : " . $blogs_json);
    
        my $MTAppSuperSlideMenu = MTAppjQuery::Tmplset::MTAppSuperSlideMenu;
        $super_slide_menu_js = <<__MTML__;
        <script type="text/javascript">
        /* <![CDATA[ */
        var mtapp_websites_json = [${websites_json}];
        var mtapp_blogs_json = [${blogs_json}];
        /* ]]> */
        </script>
        <script type="text/javascript">
        ${MTAppSuperSlideMenu}
        </script>
__MTML__
    }

    ### user.css をセットする
    if ($op_no_usercss != 1 && ($op_usercss == 1 or $blog_id == 0)) {
        $user_css = <<__MTML__;
    <mt:setvarblock name="html_head" append="1">
    <link rel="stylesheet" href="${static_plugin_path}css/user.css" type="text/css" />
    </mt:setvarblock>
__MTML__
    }

    ### ブログIDなどの変数を定義する
	$set_blog_id = <<__MTML__;
    <script type="text/javascript">
    /* <![CDATA[ */
    // 後方互換（非推奨）
    var blogID = ${blog_id},
        authorID = <mt:if name="author_id"><mt:var name="author_id"><mt:else>0</mt:if>,
        ${_type}ID = ${id},
        blogURL = '<mt:if name="blog_url"><mt:var name="blog_url"><mt:else><mt:var name="site_url"></mt:if>',
        mtappURL = '${static_plugin_path}',
        mtappTitle = '<mt:if name="html_title"><mt:var name="html_title"><mt:else><mt:var name="page_title"></mt:if>',
        mtappScopeType = '<mt:var name="scope_type">',
        catsSelected = <mt:if name="selected_category_loop"><mt:var name="selected_category_loop" to_json="1"><mt:else>[]</mt:if>,
        mainCatSelected = <mt:if name="category_id"><mt:var name="category_id"><mt:else>''</mt:if>;

    // 推奨
    var mtappVars = {
        "author_id" : <mt:if name="author_id"><mt:var name="author_id"><mt:else>0</mt:if>,
        "curr_website_id" : <mt:if name="curr_website_id"><mt:var name="curr_website_id"><mt:else>0</mt:if>,
        "blog_id" : ${blog_id},
        "entry_id" : ${entry_id},
        "page_id" : ${page_id},
        "category_id" : ${category_id},
        "template_id" : ${template_id},
        "blog_url" : '<mt:if name="blog_url"><mt:var name="blog_url"><mt:else><mt:var name="site_url"></mt:if>',
        "static_plugin_path" : '${static_plugin_path}',
        "html_title" : '<mt:if name="html_title"><mt:var name="html_title"><mt:else><mt:var name="page_title"></mt:if>',
        "scope_type" : '<mt:var name="scope_type">',
        "selected_category" : <mt:if name="selected_category_loop"><mt:var name="selected_category_loop" to_json="1"><mt:else>[]</mt:if>,
        "main_category_id" : <mt:if name="category_id"><mt:var name="category_id"><mt:else>''</mt:if>
    }
    /* ]]> */
    </script>
__MTML__

    ### JavaScriptフリーエリアの内容をセットする
    if ($blog_id == 0) {
        $js_freearea = $op_sys_jsfreearea;
    } else {
        $js_freearea = $op_jsfreearea || $op_sys_jsfreearea;
    }

    ### user.jsをセット
    if ($op_no_userjs != 1 && ($op_userjs == 1 or $blog_id == 0)) {
		$user_js = <<__MTML__;
    <script type="text/javascript" src="${static_plugin_path}js/user.js"></script>
__MTML__
	}

    ### 各情報をheadにセットする
    my $html_head = '<mt:var name="html_head">';
	my $add_html_head = <<__MTML__;
    <link rel="stylesheet" href="${static_plugin_path}css/MTAppjQuery.css" type="text/css" />
    $user_css
    <mt:setvarblock name="js_include" append="1">
    $set_blog_id
    <mt:var name="uploadify_source">
    <script type="text/javascript" src="${static_plugin_path}js/MTAppjQuery.js"></script>
    $js_freearea
    </mt:setvarblock>
    <mt:setvarblock name="mtapp_js_include">
    $user_js
    $super_slide_menu_js
    </mt:setvarblock>
    $html_head
__MTML__

	$$tmpl_ref =~ s/$html_head/$add_html_head/g;
}

sub cb_tmpl_source_footer {
	my ($cb, $app, $tmpl_ref) = @_;
    my $target = '</body>';
    my $replace = <<__MTML__;
    <script type="text/javascript">
    /* <![CDATA[ */
    <mt:var name="mtapp_js_include">
    jQuery(function(){
        <mt:var name="mtapp_jq_js_include">
        jQuery('#mtapp-loading').hide();
        jQuery('#container').css('visibility','visible');
    });
    /* ]]> */
    </script>
    <mt:var name="mtapp_end_body">
    $target
__MTML__
	$$tmpl_ref =~ s!$target!$replace!;
}

sub cb_tmpl_source_fav_blogs {
	my ($cb, $app, $tmpl_ref) = @_;

# my $user = $app->user;
# my $perms = $user->permissions( 12 );
# doLog('$user : '.Dumper($user->__meta));

	### class="parent-website-n"を付与
	my $classname = 'class="blog-content"';
    my $new_classname = 'class="blog-content parent-website-<mt:if name="blog_id"><mt:var name="website_id"><mt:else>0</mt:if>"';
    $$tmpl_ref =~ s!$classname!$new_classname!g;

    ### 構造タブを追加
    my $fav_blogs_tab_org = MTAppjQuery::Tmplset::fav_blogs_tab('before');
    my $fav_blogs_tab     = MTAppjQuery::Tmplset::fav_blogs_tab('after');
    $$tmpl_ref =~ s!$fav_blogs_tab_org!$fav_blogs_tab!g;

    ### 構造タブの中身を入れる
    my $fav_blogs_wdg_close_org = MTAppjQuery::Tmplset::fav_blogs_wdg_close_org;
    my $fav_blogs_wdg_close     = MTAppjQuery::Tmplset::fav_blogs_wdg_close;
    $$tmpl_ref =~ s!$fav_blogs_wdg_close_org!$fav_blogs_wdg_close!g;

}

# sub cb_tmpl_param_fav_blogs {
#     my ($cb, $app, $param, $tmpl) = @_;
#     $param->{'blogs_json'} = ('あ','い','う');
# }

sub cb_tmpl_param_edit_entry {
    my ($cb, $app, $param, $tmpl) = @_;
# doLog(Dumper($param));
    ### $app->
    my $host        = $app->{__host};
    my $static_path = $app->static_path;

    ### $param->
    my $blog_id   = $param->{blog_id} || 0;
    my $blog_url  = $param->{blog_url} || '';
    my $blog_path = $blog_url;
       $blog_path =~ s!^$host|\/$!!g;
# doLog('$blog_path : '.$blog_path.'  $blog_url : '.$blog_url);

    ### $p->
    my $p = MT->component('mt_app_jquery');
    my $active_uploadify = $p->get_setting('active_uploadify', $blog_id);
    my $no_uploadify     = $p->get_setting('no_uploadify', 0);
    if ($active_uploadify == 0 || $no_uploadify == 1) {
        return;
    }
    my $img  = &_config_replace($p->get_setting('img_elm', $blog_id));
    my $file = &_config_replace($p->get_setting('file_elm', $blog_id));
    
    ### Variable
    my $static_plugin_path = $static_path . $p->{envelope} . '/';
    
    ### SetVar(param)
    $param->{blog_path} = $blog_path;
    $param->{upload_folder} = $p->get_setting('upload_folder', $blog_id);
    $param->{static_plugin_path} = $static_plugin_path;
    $param->{uploadify_source} = <<__MTML__;
    <link href="${static_plugin_path}uploadify/css/uploadify.css" rel="stylesheet" type="text/css" />
    <script type="text/javascript" src="${static_plugin_path}uploadify/scripts/swfobject.js"></script>
    <script type="text/javascript" src="${static_plugin_path}uploadify/scripts/jquery.uploadify.v2.1.0.js"></script>
__MTML__
    
    ### Add uploadify-widget
    my $host_node = $tmpl->getElementById('entry-status-widget');
    my $new_node = $tmpl->createElement('app:widget',
        {
            id    => 'uploadify-widget',
            label => '<__trans_section component="mt_app_jquery"><__trans phrase="A multiple file upload"></__trans_section>',
        }
    );
    my $inner_html = MTAppjQuery::Tmplset::uploadify_widget_innerHTML;
    $inner_html =~ s!__IMAGES__!$img!g;
    $inner_html =~ s!__FILES__!$file!g;
    $new_node->innerHTML($inner_html);
    $tmpl->insertAfter($new_node, $host_node);

    ### Add asset_uploadify
    my $host_node = $tmpl->getElementById('keywords');
    my $new_node = $tmpl->createElement('app:Setting',
        {
            id    => 'asset_uploadify',
            label => '<__trans_section component="mt_app_jquery"><__trans phrase="A multiple file upload"></__trans_section>',
            label_class => 'top_label',
        }
    );
    my $inner_html = <<__MTML__;
    <input type="text" name="asset_uploadify" id="asset_uploadify" value="<mt:var name="asset_uploadify">" class="full-width" mt:watch-change="1" />
__MTML__
    $new_node->innerHTML($inner_html);
# 最後にコメント外す
    $new_node->setAttribute('class','hidden');
    $tmpl->insertAfter($new_node, $host_node);

    ### Add asset_uploadify_meta
    my $new_node = $tmpl->createElement('app:Setting',
        {
            id    => 'asset_uploadify_meta',
            label => '<__trans_section component="mt_app_jquery"><__trans phrase="A multiple file upload meta"></__trans_section>',
            label_class => 'top_label',
        }
    );
    my $inner_html = <<__MTML__;
    <input type="text" name="asset_uploadify_meta" id="asset_uploadify_meta" value="<mt:var name="asset_uploadify_meta">" class="full-width" mt:watch-change="1" />
__MTML__
    $new_node->innerHTML($inner_html);
# 最後にコメント外す
    $new_node->setAttribute('class','hidden');
    $tmpl->insertAfter($new_node, $host_node);

# doLog('End cb_tmpl_param_edit_entry!');

}

sub cb_cms_post_save_entry {
    my ($cb, $app, $obj, $orig_obj) = @_;

    require MT::Asset;
    require MT::ObjectAsset;
# doLog('Start cb_cms_post_save_entry!');
# doLog('========= $obj [start] ==========');
# doLog(Dumper($obj));
# doLog('========= $obj [ end ] ==========');
    ### $app->
    my $blog_id = $app->param('blog_id') || 0;
    my $q = $app->param;

    ### $obj->
    my $entry_id = $obj->id;
# doLog('$entry_id : '.$entry_id);

    ### $p-> ($plugin->)
    my $p = MT->component('mt_app_jquery');
    my $active_uploadify = $p->get_setting('active_uploadify', $blog_id);
    my $no_uploadify     = $p->get_setting('no_uploadify', 0);
    return if ($active_uploadify == 0 || $no_uploadify == 1);

    my $asset_uploadify = $q->param('asset_uploadify');
    my $asset_uploadify_meta = $q->param('asset_uploadify_meta');

    my $headers = [
        'queue_id',
        'asset_blog_id',
        'asset_class',
        'asset_created_by',
        #'asset_created_on',
        'asset_file_ext',
        'asset_file_name',
        'asset_file_path',
        'asset_label',
        'asset_mime_type',
        #'asset_modified_on',
        'asset_url'
    ];
    my $headers_meta = ['queue_id','image_width','image_height'];

    my $assets = _parse($asset_uploadify, $headers);
    my $assets_meta = _parse($asset_uploadify_meta, $headers_meta);

# doLog('ループ前の$assets : '.Dumper($assets));
# doLog('ループ前の$assets_meta : '.Dumper($assets_meta));

    foreach my $asset (@$assets) {
        my $obj = MT::Asset::Image->new;
# doLog('ループ中の$assets : '.Dumper($asset));
        $obj->blog_id($blog_id);
        $obj->label($asset->{asset_label});
        $obj->url($asset->{asset_url});
        $obj->file_path($asset->{asset_file_path});
        $obj->file_name($asset->{asset_file_name});
        $obj->file_ext($asset->{asset_file_ext});
        $obj->mime_type($asset->{asset_mime_type});
        $obj->class($asset->{asset_class});
        $obj->created_by($asset->{asset_created_by});
        foreach my $asset_meta (@$assets_meta) {
            if ($asset_meta->{queue_id} == $asset->{queue_id}) {
# doLog('ループ中の$assets_meta : '.Dumper($asset_meta));
                $obj->image_width($asset_meta->{image_width});
                $obj->image_height($asset_meta->{image_height});
            }
        }
        $obj->save or die 'Failed to save the item.';
    }
    my @saved_assets = MT::Asset::Image->load({
        blog_id => $blog_id,
    });
    my @curt_post_assets_id = ();
    foreach my $saved_asset (@saved_assets) {
        my $saved_asset_id = $saved_asset->id;
        my $saved_asset_filename = $saved_asset->file_name;
        foreach my $asset (@$assets) {
            if ($saved_asset_filename eq $asset->{asset_file_name}) {
                push(@curt_post_assets_id, $saved_asset_id);
            }
        }
    }
# doLog('@curt_post_assets_id : '.Dumper(@curt_post_assets_id));

    foreach my $asset_id (@curt_post_assets_id) {
        my $obj_asset = MT::ObjectAsset->new;
        $obj_asset->blog_id($blog_id);
        $obj_asset->asset_id($asset_id);
        $obj_asset->object_ds('entry');
        $obj_asset->object_id($entry_id);
# doLog('===== $obj_asset->save 直前 =====');
        $obj_asset->save or die 'Failed to save the objectasset.';
    }
# doLog('End cb_cms_post_save_entry!');
}

sub _config_replace {
    my ($str) = @_;
    $str =~ s!__filepath__!' + fileObj.filePath.replace(/\\/\\//g,"/") + '!g;
    $str =~ s!__filename__!' + fileObj.name + '!g;
    return $str;
}

sub _parse {
    # http://d.hatena.ne.jp/perlcodesample/touch/20080621/1214058703
    my ($text, $headers) = @_;
    
    my @lines = split('\|', $text);
    
    my $items_hash_list = [];
    foreach my $line (@lines){
        my @items = split(',', $line);
        my %items_hash = ();
        @items_hash{ @{ $headers } } = @items;
        push @{ $items_hash_list },{ %items_hash };
    }
    wantarray ? return @{ $items_hash_list } : return $items_hash_list;
}

1;