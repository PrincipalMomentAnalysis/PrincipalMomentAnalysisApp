@testset "content" begin
	doc = read("../src/content.html",String)
	@test occursin("""<script type="text/javascript">""", doc)
end