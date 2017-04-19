ActiveAdmin.register Project do
  title_translations = []
  desc_translations = []
  Crowdbreaks::Locales.each do |l|
    title_translations.push(('title_'+l).to_sym)
    desc_translations.push(('description_'+l).to_sym)
  end
  permit_params *title_translations, *desc_translations


  index do
    column "Title" do |p|
      p.title_translations['en']
    end
    column "Description" do |p|
      p.description_translations['en'] if p.desc_translations
    end
    column :created_at
    column :updated_at
    actions
  end

  form do |f|
    f.inputs "Project" do
      title_translations.each do |t|
        f.input t
      end
      desc_translations.each do |t|
        f.input t, as: :text
      end
    end
    f.actions
  end
end
