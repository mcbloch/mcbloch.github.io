def _contact_point link, icon, property
    <<-HTML
<a href="#{link[:uri]}" property="#{property}">
    <i class="icon #{icon}"></i>#{link[:text]}
</a>
       HTML
end

def contact_point link
  case link[:type]
  when "phone"
    _contact_point link, "fa-solid fa-phone", "schema:telephone foaf:phone"
  when "email"
    _contact_point link, "fa-solid fa-envelope", "schema:email foaf:mbox"
  when "homepage"
    _contact_point link, "fa-solid fa-home", "foaf:homepage"
  when "github"
    _contact_point link, "fa-brands fa-github", "foaf:account"
  when "linkedin"
    _contact_point link, "fa-brands fa-linkedin-in", "foaf:account"
  else
    <<-HTML
<b class="todo"> INVALID TYPE </b>
       HTML
  end
end

def edu_type education
    case education[:type]
    when "master"
        "cvb:EduMaster"
    when "bachelor"
        "cvb:EduBachelor"
    when "highschool"
        "cvb:EduHighSchool"
    else
      raise "Invalid education type" + education[:type]
    end
end
