-- The Art Institute of Chicago's image server refuses downloads from the
-- mirror workflow (GitHub runners), so these three works go back to the
-- public-domain Commons images they had before 20261027040100_image_credits.sql.

update public.artworks set
    image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f5/The_Child%27s_Bath_by_Mary_Cassatt_1893.jpg/960px-The_Child%27s_Bath_by_Mary_Cassatt_1893.jpg',
    image_license = 'Public domain',
    image_credit = null,
    image_page = 'https://commons.wikimedia.org/wiki/File:The_Child%27s_Bath_by_Mary_Cassatt_1893.jpg'
where image_url = 'https://www.artic.edu/iiif/2/3b885ae0-4d46-5fe4-d70a-00474827f02c/full/843,/0/default.jpg';
update public.artworks set
    image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/1/10/Henri_de_Toulouse-Lautrec_-_At_the_Moulin_Rouge_-_1928.610_-_Art_Institute_of_Chicago.jpg/960px-Henri_de_Toulouse-Lautrec_-_At_the_Moulin_Rouge_-_1928.610_-_Art_Institute_of_Chicago.jpg',
    image_license = 'Public domain',
    image_credit = null,
    image_page = 'https://commons.wikimedia.org/wiki/File:Henri_de_Toulouse-Lautrec_-_At_the_Moulin_Rouge_-_1928.610_-_Art_Institute_of_Chicago.jpg'
where image_url = 'https://www.artic.edu/iiif/2/defb4004-b500-218d-3d9b-9a02423f097d/full/843,/0/default.jpg';
update public.artworks set
    image_url = 'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/38/Paul_C%C3%A9zanne_-_The_Basket_of_Apples_-_1926.252_-_Art_Institute_of_Chicago.jpg/960px-Paul_C%C3%A9zanne_-_The_Basket_of_Apples_-_1926.252_-_Art_Institute_of_Chicago.jpg',
    image_license = 'Public domain',
    image_credit = null,
    image_page = 'https://commons.wikimedia.org/wiki/File:Paul_C%C3%A9zanne_-_The_Basket_of_Apples_-_1926.252_-_Art_Institute_of_Chicago.jpg'
where image_url = 'https://www.artic.edu/iiif/2/52ac8996-3460-cf71-cb42-5c4d0aa29b74/full/843,/0/default.jpg';
