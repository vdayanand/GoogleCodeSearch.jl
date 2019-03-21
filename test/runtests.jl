using GoogleCodeSearch
using Test

const test_data = [
(path="path1", file="file1", content="""
path1, file1, line1
path1, file1, line2
"""),
(path="path1", file="file2", content="""
path1, file2, line1
path1, file2, line2
"""),
(path="path2", file="file1", content="""
path2, file1, line1
path2, file1, line2
"""),
(path="path2", file="file2", content="""
path2, file2, line1
path2, file2, line2
"""),
(path="path22", file="file1", content="""
path22, file1, line1
path22, file1, line2
"""),
(path="path22", file="file2", content="""
path22, file2, line1
path22, file2, line2
""")
]

# split index on the last alphabet of path component of test_data
test_index_resolver(ctx::Ctx, inpath::String) = joinpath(ctx.store, "index" * rsplit(inpath, '/'; limit=2)[1][end])

function test_noindices(ctx::Ctx)
    @test isempty(paths_indexed(ctx))
    @test isempty(indices(ctx))
    @test isempty(search(ctx, ".*"; ignorecase=true))

    # clear_indices should not error out if there are no indices
    @test clear_indices(ctx) === nothing
    nothing
end

function test_indexing(ctx::Ctx, datadir::String)
    paths = Set(joinpath(datadir, item.path) for item in test_data)
    for path in paths
        @test index(ctx, path)
        @test !isempty(indices(ctx))
        @test any(occursin(x, path) for x in paths_indexed(ctx))
    end
    all_paths = paths_indexed(ctx)
    @test !("/nosuchpath" in all_paths)
    # test that `path2` subsumes `path22`
    @test !any(occursin("path22", x) for x in all_paths)
    nothing
end

function test_search(ctx::Ctx, datadir::String)
    # test case sensitiveness
    @test isempty(search(ctx, "File"))
    @test !isempty(search(ctx, "File"; ignorecase=true))

    # test pathfilter
    for ignorecase in (true, false)
        res = search(ctx, "Line1"; ignorecase=ignorecase, pathfilter=".*/path1/.*")
        if ignorecase
            @test length(res) == 2
            for item in res
                @test item.line == 1
                @test endswith(strip(item.text), "line1")
                @test occursin("path1", item.file)
            end
        else
            @test isempty(res)
        end
    end

    # test split indices
    for ignorecase in (true, false)
        res = search(ctx, "Line2"; ignorecase=ignorecase)
        if ignorecase
            @test length(res) == length(test_data)
            for item in res
                @test item.line == 2
                @test endswith(strip(item.text), "line2")
                @test occursin("path", item.file)
            end
        else
            @test isempty(res)
        end
    end
    nothing
end

function create_test_data(datadir::String)
    for item in test_data
        dir = joinpath(datadir, item.path)
        mkpath(dir)
        open(joinpath(dir, item.file), "w") do f
            println(f, item.content)
        end
    end
end

function all_tests(testdir)
    storedir = joinpath(testdir, "store") 
    datadir = joinpath(testdir, "data")
    create_test_data(datadir)
    mkpath(storedir)

    ctx = Ctx(store=storedir)
    test_noindices(ctx)
    test_indexing(ctx, datadir)
    test_search(ctx, datadir)

    @test clear_indices(ctx) === nothing
    test_noindices(ctx)
    nothing
end

mktempdir() do testdir
    all_tests(testdir)
end