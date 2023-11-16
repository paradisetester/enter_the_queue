import Layout from "../../components/Layout"
import { Details } from "../../components/creators";
import { getBaseUrl } from "helpers/axios";
import { formatUserData, getAllItems } from "services";
import { useEffect, useState } from "react";


export default function BaseCreator({ user, id, query }: any) {

    const [isLoading, setIsLoading] = useState(false);
    const [filters, setFilters] = useState<any>(query);
    const [updated, setUpdated] = useState<Boolean>(false);
    const [nfts, setNfts] = useState<any[]>([]);
    const [collected, setCollected] = useState<any[]>([]);



    useEffect(() => {
        (async () => {
            setIsLoading(true);
            if (user.ownedNftCount) {
                // Get creator owned nfts
                const collectedNfts = await getAllItems({
                    ...filters,
                    ownedBy: id,
                    limit: 20
                });
                setCollected(collectedNfts);
            }
            if (user.createdNftCount) {

                const items = await getAllItems({
                    ...filters,
                    createdBy: id,
                    limit: 20
                });
                setNfts(items);
            }
            setIsLoading(false);
        })();
    }, [updated, filters, id, user.createdNftCount, user.ownedNftCount])


    const handleSearch = async (data = {}) => {
        if (Object.keys(data).length) {
            setFilters(data);
        } else {
            setFilters(data);
        }
        setUpdated(!updated);
    }

    return (
        <Layout isLoading={isLoading}>
            <Details
                nfts={nfts}
                collected={collected}
                id={id}
                creator={user}
                useFilter={() => [filters, handleSearch]}
            />
        </Layout>
    )
}

export const getServerSideProps = async (context: any) => {
    const { creatorId }: any = context.query;
    const user = await fetch(getBaseUrl(`api/users/${creatorId}`))
        .then(res => res.json())
        .then(res => formatUserData(res.data));

    if (Object.keys(user).length) {
        return { props: { user, id: creatorId, query: context.query || {} } };
    }
    return {
        notFound: true
    }
}